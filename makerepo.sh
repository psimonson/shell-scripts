#!/bin/sh
# Created by Philip R. Simonson

if [[ $# -lt 2 || $# -gt 5 ]]
then
	echo "Usage: $0 <reponame> <description> [private:true] [has_wiki:false]"
	exit 1
else
	private=true
	wiki=false

	if [ $# -eq 3 ]
	then
		private="$3"
	elif [ $# -eq 4 ]
	then
		private="$3"
		wiki="$4"
	fi

	curl -u psimonson -H 'Authorization: token <your-token>' -d "{\"name\": \"$1\", \"description\": \"$2\", \"private\": $private, \"has_issues\": true, \"has_wiki\": $wiki}" https://api.github.com/user/repos
	if [ $? -eq 0 ]
	then
		echo "Success!"
	else
		echo "Failed!"
	fi
fi

