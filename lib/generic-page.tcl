set place [parameter::get -parameter PlaceReference]

# place is a metadata path: something like /site-map/dashboard/

# Using ns_normalizepath to get rid of the trailing slash:
set master [dotkul::get_metadata [ns_normalizepath $place].master]

# Find current page
set url [ad_conn extra_url]

if { [empty_string_p $url] } {
    # We interpret the extra url stub as the page-folder.  As there is no extra
    # URL we redirect to the default page-folder.  For now we just take the
    # first (random) one.  After redirect we'll come back here.

    ad_returnredirect [lindex [dotkul::get_metadata $place] 0]/
    return
}

# Trailing slash in the URL is interpreted as: "Use the default page".  The
# default page is always called "index":

if { [string match "*/" "/$url"] } {
    set page ${place}${url}index
} else {
    set page ${place}${url}
}

set title [dotkul::get_metadata $page.title]
