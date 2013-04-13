#!/bin/zsh

#
# ZSH Share Storage Module
#
 
zmodload zsh/net/tcp
 
zss_server_fd=0
typeset -A zss_storage;
 
function zss_open()
{
	local port
	port=$(($RANDOM + 32767))
	ztcp -l $port
	zss_server_fd=$REPLY
	(zss_start_server >/dev/null 2>/dev/null &)
	ztcp localhost $port
	return $REPLY
}
 
function zss_close()
{
	echo "close" >&$1
	ztcp -c $1
}
 
function zss_read()
{
	echo "read $2" >&$1
	read -r line <&$1
	echo $line
}
 
function zss_write()
{
	echo "write $2 $3" >&$1
}
 
function zss_start_server()
{
	ztcp -a $zss_server_fd
	local fd=$REPLY
	while [ true ]; do
		read -r line <&$fd
		if [ "$?" -eq "1" ]; then
			break
		fi
		local req
		eval "req=($line)"
		case "$req[1]" in
			read)
				echo $zss_storage[$req[2]] >&$fd
				;;
			write)
				zss_storage[$req[2]]="$req[3]"
				;;
			close)
				break
				;;
		esac
	done
	ztcp -c $fd
	ztcp -c $zss_server_fd
}
