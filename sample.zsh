#!/bin/zsh

TW_LOAD_AS_MODULE=1

source tw
source json.zsh

count=1

json="$(get "http://api.twitter.com/1.1/statuses/home_timeline.json" "count $count")"
_json_init "$json"
statuses=$(_json_parse_value)


for i in {1..$count}; do
	eval echo $(_json_get $statuses $i user screen_name)
	eval echo $(_json_get $statuses $i text)
done

