source binutils.zsh

function _array_toarray()
{
	if [ "$LANG" != "C" ]; then
		LANG=C _array_toarray "$1"
	else
		echo -n "("$(for ((i=1; i<=$#1; i+=1)) do echo -n " $((0x$(toint ${1[$i]})))"; done)")"
	fi
}
