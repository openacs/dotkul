
set place [parameter::get -parameter PlaceReference]

set master [dotkul::get_metadata [string range $place 0 end-1].master]

# Find current page
set url [ad_conn extra_url]

if { [empty_string_p $url] } {
    ad_returnredirect [lindex [dotkul::get_metadata $place] 0]/
    return
}

# Add trailing 'index', if necessary
if { [string match "*/" "/$url"] } {
    append url "index"
}

set page $place$url

set title [dotkul::get_metadata $page.title]

