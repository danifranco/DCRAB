#!/bin/bash
# DCRAB SOFTWARE
# Version: 2.0
# Author: CC-staff
# Donostia International Physics Center
#
# ===============================================================================================================
#
# Check submission script to activate the internal report of DCRAB if it isn't defined yet in PBS scheduler
#
# ===============================================================================================================

if [ "$1" != "" ]; then
	# Check if DCRAB is activate 
	start=$(cat $1 | grep "dcrab start" | grep -q -v "^#"; echo $?)
	finish=$(cat $1 | grep "dcrab finish" | grep -q -v "^#"; echo $?)
	istart=$(cat $1 | grep "dcrab istart" | grep -q -v "^#"; echo $?)
	ifinish=$(cat $1 | grep "dcrab ifinish" | grep -q -v "^#"; echo $?)

	# To fix if there is no 'finish' clause defined but yes the 'start'
        if [[ $start -eq 0 ]] && [[ $finish -eq 1 ]]; then
                echo "dcrab finish" >> $1
		finish=0
        fi

	# To fix if there is no 'ifinish' clause defined but yes the 'istart'
        if [[ $istart -eq 0 ]] && [[ $ifinish -eq 1 ]]; then
                echo "dcrab ifinish" >> $1
		ifinish=0
        fi

	# If DCRAB is not activated yet
	if [[ $start -ne 0 ]] && [[ $finish -ne 0 ]]; then

		# If the internal report is not activated 
		if [[ $istart -ne 0 ]] && [[ $ifinish -ne 0 ]]; then
			# Determine the position to insert 
                        position=$(grep -n "#PBS" $1 | tail -1 | cut -d':' -f1)

			# Insert DCRAB lines
			shell_type=$(cat $1 | grep "#\!")
			echo $shell_type | grep -q "bash"
			if [ $? -eq 0 ]; then
	                	sed -i "$position"'s|$|\nexport DCRAB_PATH=/scratch/administracion/admin/dcrab/software/src\nexport PATH=$PATH:$DCRAB_PATH\ndcrab istart\n|' $1
			else
				sed -i "$position"'s|$|\nsetenv DCRAB_PATH /scratch/administracion/admin/dcrab/software/src\nsetenv PATH $PATH\\:$DCRAB_PATH\ndcrab istart\n|' $1	
			fi
			echo "dcrab ifinish" >> $1
		fi
	fi
fi

