address=$kserver
echo "${address/%.2\//.1}" | cut -d '/' -f 3