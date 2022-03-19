#!/bin/sh

q=/tmp/mireaschedule
schedule="schedule"
mireagroup='ИАБО-01-19'
institute=''
get_schedule(){
	mireagroup=$(echo $mireagroup | tr [:lower:] [:upper:] )
	course=$(echo "$(date +"%y") $(echo $mireagroup | sed -e 's/[^-]*-//g')-$(date +"%m") 7/+p" | dc)
	case $(echo $mireagroup | sed 's/\(^.\).*/\1/g') in
		И)
			institute='ИИТ'
			;;
		К)
			institute='ИИИ'
			;;
		У)
			institute='ИТУ'
			;;
		Х)
			institute='ИТХТ'
			;;
		*)
			exit 250;
	esac
	mkdir $q
	if curl -o $q/$schedule -L 'https://www.mirea.ru/schedule' 2> /dev/null
	then
		url="$(grep -io "https:[^\"\'_]*${institute}_${course}[^.\\]*[во][ес][се]н[аь][^\"\']*" < $q/$schedule | sed 's/ /%20/g')"
		echo $url
		if curl -v -L -o $q/$schedule "$url" 2> /dev/null
		then
			cd $q || exit 240
			xlsx2csv -d '~' -e $q/$schedule $q/$schedule.csv || exit 241
			column=$(sed -n '2p' < $q/$schedule.csv | tr '~' '\n' | nl -ba | sed -n "s/  */ /g;/${mireagroup}/p" | cut -f1)
			if [ column = '' ]
			then
				exit 242
			fi
			columns="$(expr $column + 1 - 1),$(expr $column + 1),$(expr $column + 2),$(expr $column + 3),$(expr $column + 4)"
			dothat="cut -d~ -f1,2,3,4,5,${columns}"
			cut -d~ -f1,2,3,4,5,${columns} < ${q}/${schedule}.csv | sed -e 's/^\([^~]*\)/\1\n/' | sed '/^$/d' | sed -e 's/^\([^~Дд]\)/MARK\n\1/; /Начальник[[:space:]]*УМУ/q' | csplit -s - '/MARK/' '{*}'
			rm $q/xx00
		else
			return $?
		fi
		rm -f $schedule
	else
		return $?
	fi
}

week=$(echo "$(date +"%W")" 5-p | dc)
day=$(date +"%u")

while [ $# -ne 0 ]
do
	case $1 in
		tw| эн)
			printf 'Сейчас %d неделя\n' $week
			day='*'
			;;
		t | з)
			if [ "${day}" -eq 6 ]
			then
				echo 'Сегодня суббота, а завтра восресенье!' >&2
				exit 2;
			fi
			day=$(echo "${day} 7%1+p" | dc)
			;;
		n | nw | сн)
			week=$(echo "${week} 1+p"|dc)
			printf 'Следующая неделя - %d ая\n' $week
			day='*'
			;;
		a | all | все)
			week=0
			day='*'
			;;
		*)
			;;
	esac
	shift
done

if [ "${day}" = '7' ]
then
	echo 'Сегодня воскресенье!' >&2
	exit 2;
fi

if [ "${week}" -ne 0 ]
then
	week=$(echo "$week 1+2%2+p" | dc)
	week=",${week}"
fi

get_schedule
for x in ${q}/xx0${day}
do
	sed -e "1${week}d;s/~[^I]*II*~//" < "$x" | sed -e "s/^~.*//;{N;P;d}" | sed '/./=' | sed '/./N; s/\n/\t/; /^$/d; s/\\n/ /g' | column -t -s'~'
done
rm -rf $q
