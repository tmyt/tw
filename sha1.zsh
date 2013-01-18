source binutils.zsh
source array.zsh

function _sha1_f00()
{
	echo -n $((($1 & $2)|((0xffffffff - $1) & $3)))
}

function _sha1_f20()
{
	echo -n $(($1 ^ $2 ^ $3))
}

function _sha1_f40()
{
	echo -n $((($1 & $2)|($1 & $3)|($2 & $3)))
}

function _sha1_f60()
{
	echo -n $(($1 ^ $2 ^ $3))
}

function _sha1_circlar_shift()
{
	echo -n $(((($2 << $1) & 0xffffffff)|(($2 >> (32 - $1)) & 0xffffffff)))
}

function _sha1_ulong_hex()
{
	local table
	table="0123456789ABCDEF"
	for ((i=1; i<=8; i+=1)) do
		echo -n $table[$(((($1 >> (32 - $i*4)) & 0xf)+1))]
	done
}

function _sha1_hash()
{
	local len buffer i
	eval buffer=$(_array_toarray $1)
	len=$(($#buffer * 8))
	# extends
	buffer[$(($#buffer + 1))]=$((0x80))
	for ((i=$(($#buffer % 64 + 1)); i<=56; i+=1)) do
		buffer[$(($#buffer + 1))]=0
	done
	buffer[$(($#buffer + 1))]=$((($len >> 52) & 0xff))
	buffer[$(($#buffer + 1))]=$((($len >> 48) & 0xff))
	buffer[$(($#buffer + 1))]=$((($len >> 40) & 0xff))
	buffer[$(($#buffer + 1))]=$((($len >> 32) & 0xff))
	buffer[$(($#buffer + 1))]=$((($len >> 24) & 0xff))
	buffer[$(($#buffer + 1))]=$((($len >> 16) & 0xff))
	buffer[$(($#buffer + 1))]=$((($len >> 8) & 0xff))
	buffer[$(($#buffer + 1))]=$((($len >> 0) & 0xff))

	local K
	K=($((0x5A827999)) $((0x6ED9EBA1)) $((0x8F1BBCDC)) $((0xCA62C1D6)))

	# calc digest
	local A B C D E H0 H1 H2 H3 H4 W TMP index
	H0=$((0x67452301))
	H1=$((0xEFCDAB89))
	H2=$((0x98BADCFE))
	H3=$((0x10325476))
	H4=$((0xC3D2E1F0))
	W=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
	index=0
	while [ $index -lt $(($#buffer / 64)) ]; do
		for ((i=1; i<=80; i+=1)) do W[$i]=0; done
		# step a
		for ((i=0; i<16; i+=1)) do
			W[$(($i+1))]=$((($buffer[$(($i*4+1+($index*64)))]<<24)|($buffer[$(($i*4+2+($index*64)))]<<16)|($buffer[$(($i*4+3+($index*64)))]<<8)|($buffer[$(($i*4+4+($index*64)))])))
		done
		# step b
		for ((i=16; i<80; i+=1)) do
			W[$(($i+1))]=$(_sha1_circlar_shift 1 $(($W[$(($i-2))]^$W[$(($i-7))]^$W[$(($i-13))]^$W[$(($i-15))])))
		done
		# step c
		A=$H0
		B=$H1
		C=$H2
		D=$H3
		E=$H4
		# step d
		for ((i=1; i<=20; i+=1)) do
			TMP=$((($(_sha1_circlar_shift 5 $A) + $(_sha1_f00 $B $C $D) + $E + $W[$i] + $K[1]) & 0xffffffff))
			E=$D
			D=$C
			C=$(_sha1_circlar_shift 30 $B)
			B=$A
			A=$TMP
		done
		for ((i=21; i<=40; i+=1)) do
			TMP=$((($(_sha1_circlar_shift 5 $A) + $(_sha1_f20 $B $C $D) + $E + $W[$i] + $K[2]) & 0xffffffff))
			E=$D
			D=$C
			C=$(_sha1_circlar_shift 30 $B)
			B=$A
			A=$TMP
		done
		for ((i=41; i<=60; i+=1)) do
			TMP=$((($(_sha1_circlar_shift 5 $A) + $(_sha1_f40 $B $C $D) + $E + $W[$i] + $K[3]) & 0xffffffff))
			E=$D
			D=$C
			C=$(_sha1_circlar_shift 30 $B)
			B=$A
			A=$TMP
		done
		for ((i=61; i<=80; i+=1)) do
			TMP=$((($(_sha1_circlar_shift 5 $A) + $(_sha1_f60 $B $C $D) + $E + $W[$i] + $K[4]) & 0xffffffff))
			E=$D
			D=$C
			C=$(_sha1_circlar_shift 30 $B)
			B=$A
			A=$TMP
		done
		# step e
		H0=$((($H0 + $A) & 0xffffffff))
		H1=$((($H1 + $B) & 0xffffffff))
		H2=$((($H2 + $C) & 0xffffffff))
		H3=$((($H3 + $D) & 0xffffffff))
		H4=$((($H4 + $E) & 0xffffffff))
		index=$(($index + 1))
	done

	# output
	_sha1_ulong_hex $H0
	_sha1_ulong_hex $H1
	_sha1_ulong_hex $H2
	_sha1_ulong_hex $H3
	_sha1_ulong_hex $H4
}
