set place [parameter::get -parameter PlaceReference]

set master [dotkul::get_metadata [string range $place 0 end-1].master]

# Find current page
set url [ad_conn extra_url]

if { [empty_string_p $url] } {
    # User has specified the place in the URL but not which page-folder in the
    # place.  We redirect to the default page-folder.  For now we just take the
    # first one.  After redirect we'll come back here.
    ad_returnredirect [lindex [dotkul::get_metadata $place] 0]/
    return
}

# Add trailing 'index', if necessary
if { [string match "*/" "/$url"] } {
    append url "index"
}

set page $place$url

set title [dotkul::get_metadata $page.title]
