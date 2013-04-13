#!/bin/zsh

#
# Pure ZSH json parser
#

source binutils.zsh
source zss.zsh

_json_buffer=''
_json_fd=0

function isspace()
{
	if [ "$1" = " " ] || [ "$1" = "" ]; then
		echo -n "t"
		return 0;
	fi
	return 1
}

function isnumber()
{
	case "$1" in
		"0"|"1"|"2"|"3"|"4"|"5"|"6"|"7"|"8"|"9")
			echo -n "t"
			return 0
	 		;;
	esac
	return 1
}

function isalnum()
{
	case "$1" in
		"0"|"1"|"2"|"3"|"4"|"5"|"6"|"7"|"8"|"9"|"A"|"B"|"C"|"D"|"E"|"F"|"G"|"H"|"I"|"J"|"K"|"L"|"M"|"N"|"O"|"P"|"Q"|"R"|"S"|"T"|"U"|"V"|"W"|"X"|"Y"|"Z"|"a"|"b"|"c"|"d"|"e"|"f"|"g"|"h"|"i"|"j"|"k"|"l"|"m"|"n"|"o"|"p"|"q"|"r"|"s"|"t"|"u"|"v"|"w"|"x"|"y"|"z")
			echo -n "t"
			return 0
	 		;;
	esac
	return 1
}

function isxdigit()
{
	case "$1" in
		"0"|"1"|"2"|"3"|"4"|"5"|"6"|"7"|"8"|"9"|"A"|"B"|"C"|"D"|"E"|"F"|"a"|"b"|"c"|"d"|"e"|"f")
			echo -n "t"
			return 0
	 		;;
	esac
	return 1
}

function _json_skip()
{
	while [ -n "$(isspace $(_json_peek_any_char))" ]; do
		_json_lex_any_char > /dev/null
	done
}

function _json_peek_any_char()
{
	local _json_index
	_json_index=$(zss_read $_json_fd index)
	if [ $#_json_buffer -lt $_json_index ]; then
		echo -n "EOF"
		zss_close $_json_fd
		return 1
	fi
	echo -n "${_json_buffer[$_json_index]}"
}

function _json_lex_any_char()
{
	local _json_index
	_json_index=$(zss_read $_json_fd index)
	c=$(_json_peek_any_char)
	if [ "$c" != "EOF" ]; then
		_json_index=$(($_json_index + 1))
		zss_write $_json_fd index $_json_index
	fi
	echo -n $c
}

function _json_lex_one_char()
{
	local i
	for ((i=1; i<=$#1; i+=1)); do
		if [ -n "$(_json_lex_char ${1[$i]})" ]; then
			echo -n ${1[$i]}
			return 0
		fi
	done
	return 1
}

function _json_peek_one_char()
{
	local i
	for ((i=1; i<=$#1; i+=1)); do
		_json_peek_char ${1[$i]}
		if [ $? -eq 0 ]; then
			echo -n ${1[$i]}
			return 0
		fi
	done
	return 1
}

function _json_peek_char()
{
	local c
	c=$(_json_peek_any_char)
	if [ "$c" = "$1" ]; then
		echo -n "$1"
		return 0
	fi
	return 1
}

function _json_lex_char()
{
	if [ -n "$(_json_peek_char $1)" ]; then
		_json_lex_any_char
		return 0
	fi
	return 1
}

function _json_lex_hex_digit()
{
	local __c
	__c=$(_json_peek_any_char)
	if [ -z "$(isxdigit $__c)" ]; then
		return 1
	fi
	_json_lex_any_char > /dev/null
	echo -n $__c
	return 0
}

function _json_parse_pair()
{
	_json_skip
	local str
	if [ -n "$(_json_peek_char '"')" ]; then
		str=$(_json_parse_string)
	else
		str=$(_json_parse_symbol)
	fi
	_json_skip
	if [ -z "$(_json_lex_char ':')" ]; then
		if [ -n "$(_json_peek_char ',')" ]; then
			echo "Error: Object value not found" > /dev/stderr
			echo -n "('$str' '')"
			return 0
		else
			echo "Error: Can't find ':' between object and value" > /dev/stderr
		fi
	fi

	local obj
	obj=$(_shell_escape "$(_json_parse_value)")
	echo -n " '$str' $obj"
}

function _json_parse_char()
{
	_json_peek_char '"'
	if [ $? -eq 0 ]; then
		echo "Error: Character contains \"" > /dev/stderr
	fi
	if [ -z "$(_json_lex_char '\')" ]; then
		_json_lex_any_char
		return 0
	fi
	local c
	c="$(_json_lex_any_char)"
	case $c in
		"EOF")
			echo "Error: Could not lex" > /dev/stderr
			;;
		'"')
			echo -n '"'
			;;
		'\\')
			echo -n '\\'
			;;
		'/')
			echo -n '/'
			;;
		'b')
			echo -n -e '\\b'
			;;
		'f')
			echo -n -e '\\f'
			;;
		'n')
			echo -n -e '\\n'
			;;
		'r')
			echo -n -e '\\r\'
			;;
		't')
			echo -n -e '\\t'
			;;
		'u')
			local a b d
			a="$(_json_lex_hex_digit)"
			b="$(_json_lex_hex_digit)"
			c="$(_json_lex_hex_digit)"
			d="$(_json_lex_hex_digit)"
			if [ -n "$a" ] &&
			   [ -n "$b" ] &&
			   [ -n "$c" ] &&
			   [ -n "$d" ]; then
				echo -n -e \\u$a$b$c$d
			else
				echo "Error: \\uXXXX format must 4 hex digits" > /dev/stderr
				echo -n "."
			fi
			;;
		*)
			echo "Error: Invalid escape sequence" > /dev/stderr
			echo -n "."
			;;
	esac
}

function _json_parse_symbol()
{
	local result
	result=""
	isalnum "$(_json_peek_any_char)" > /dev/null
	while [ $? -eq 0 ]; do
		result="$result$(_json_lex_any_char)"
		isalnum "$(_json_peek_any_char)" > /dev/null
	done
	echo -n "$result"
}

function _json_parse_string()
{
	if [ -z "$(_json_lex_char '"')" ]; then
		echo "Error: String must starting with '\"'" > /dev/stderr
	fi
	while [ true ]; do
		if [ "$(_json_peek_any_char)" = "EOF" ]; then
			echo "Error: can't find trailing '\"'" > /dev/stderr
			return 1
		fi
		if [ -n "$(_json_lex_char '"')" ]; then
			return 0
		fi
		_json_parse_char
	done
}

function _json_parse_digits()
{
	local result c
	result=""
	c="$(_json_lex_one_char "0123456789")"
	while [ -n "$c" ]; do
		echo -n $c
		c="$(_json_lex_one_char "0123456789")"
	done
}

function _json_parse_number()
{
	local sign p intpart fracpart exppart
	sign=$(_json_lex_one_char '-+')
	p=$(_json_lex_one_char "0123456789")
	if [ -z  "$p" ]; then
		echo "Error: Can't find number value" > /dev/stderr
		echo -n "0.0"
		return 0
	fi
	intpart=$p
	if [ "$p" = "0" ]; then
		if [ -n "$(_json_lex_one_char 'xX')" ]; then
			echo "Error: JSON is not supported Hex Value" > /dev/stderr
		elif [ -n "$(_json_peek_one_char '0123456789')" ]; then
			echo "Error: JSON is not supported Octet Value" > /dev/stderr
		fi
	fi
	intpart="$intpart$(_json_parse_digits)"
	fracpart=""
	if [ -n "$(_json_lex_char '.')" ]; then
		fracpart=".$(_json_parse_digits)"
		if [ $#fracpart -eq 1 ]; then
			echo "Error: Required 1 more digits after period" > /dev/stderr
			fracpart=".0"
		fi
	fi
	exppart=""
	if [ -n "$(_json_lex_one_char 'eE')" ]; then
		exppart="e"
		if [ -n "$(_json_lex_one_char '-')" ]; then
			exppart="e-"
		fi
		local digits
		digits=$(_json_parse_digits)
		if [ -z "$digits" ]; then
			echo "Error: Required 1 more digits after E sign" > /dev/stderr
			digits="0"
		fi
		exppart="$exppart$digits"
	fi
	echo -n $(($sign$intpart$fracpart$exppart))
}

function _json_parse_object()
{
	if [ -z "$(_json_lex_char '{')" ]; then
		echo "Error: object must started with '{'" > /dev/stderr
	fi
	_json_skip
	if [ -n "$(_json_lex_char '}')" ]; then
		echo -n "()"
		return 0;
	fi
	echo -n "("
	_json_parse_pair
	while [ true ]; do
		_json_skip
		if [ "$(_json_peek_any_char)" = "EOF" ]; then
			echo "Error: ']' is not found" > /dev/stderr
			echo -n ")"
			return 1
		fi
		if [ -n "$(_json_lex_char '}')" ]; then
			echo -n ")"
			return 0
		fi
		if [ -n "$(_json_lex_char ',')" ]; then
			_json_skip
			if [ -n "$(_json_lex_char '}')" ]; then
				echo "Error: JSON is not accepable trailing ','" > /dev/stderr
				echo -n ")"
				return 1
			fi
		else
			echo "Error: JSON requires ',' between object values" > /dev/stderr
		fi
		_json_parse_pair
	done
}

function _json_parse_array()
{
	if [ -z "$(_json_lex_char '[')" ]; then
		echo "Error: array must started with '['" > /dev/stderr
	fi
	_json_skip
	if [ -n "$(_json_lex_char ']')" ]; then
		echo -n "()"
		return 0;
	fi
	echo -n "("
	echo -n "$(_shell_escape "$(_json_parse_value)")"
	while [ true ]; do
		_json_skip
		if [ "$(_json_peek_any_char)" = "EOF" ]; then
			echo "Error: ']' is not found" > /dev/stderr
			echo -n ")"
			return 1
		fi
		if [ -n "$(_json_lex_char ']')" ]; then
			echo -n ")"
			return 0
		fi
		if [ -n "$(_json_lex_char ',')" ]; then
			_json_skip
			if [ -n "$(_json_lex_char ']')" ]; then
				echo "Error: JSON is not accepable trailing ','" > /dev/stderr
				echo -n ")"
				return 1
			fi
		else
			echo "Error: JSON requires ',' between array values" > /dev/stderr
		fi
		echo -n "$(_shell_escape "$(_json_parse_value)")"
	done
}

function _json_parse_value()
{
	local tmp
	_json_skip
	if [ -n "" ]; then 
	elif [ -n "$(_json_peek_char '"')" ]; then
		echo -n "'$(_json_parse_string)'"
		return 0
	elif [ -n "$(_json_peek_one_char '0123456789')" ]; then
		_json_parse_number
		return 0
	elif [ -n "$(_json_peek_char '{')" ]; then
		_json_parse_object
		return 0
	elif [ -n "$(_json_peek_char '[')" ]; then
		_json_parse_array
		return 0
	fi

	local symbol
	symbol=$(_json_parse_symbol)

	if [ -z "$symbol" ]; then
		echo "Error: can't lex value" > /dev/stderr
		_json_lex_any_char > /dev/null
		return 1
	fi
	if [ "$symbol" = "true" ]; then
		echo -n "true"
		return 0
	fi
	if [ "$symbol" = "false" ]; then
		echo -n "false"
		return 0
	fi
	if [ "$symbol" = "null" ]; then
		echo -n "null"
		return 0
	fi
	echo $symbol
	return 1
}

function _shell_escape()
{
	_bin_hexdump "$1"
}

function _json_get()
{
	local obj json
	json=$1
	shift 1
	if [ -n "$(isnumber "$1")" ]; then
		typeset -a obj
	else
		typeset -A obj
	fi
	eval obj=$json
	while [ -n "$1" ]; do
		json=$(_bin_hexrestore "$(echo -n "$obj[$1]")")
		shift 1
		if [ -z "$1" ]; then
			echo $json
			return 0
		fi
		if [ -n "$(isnumber "$1")" ]; then
			typeset -a obj
		else
			typeset -A obj
		fi
		eval obj=$json
	done
	echo $obj
}

function _json_init()
{
	_json_buffer=$1
	zss_open
	_json_fd=$?
	zss_write $_json_fd index 1
}
