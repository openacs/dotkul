# header_stuff
if { ![info exists header_stuff] } {
    set header_stuff {}
}

# Account
set account_name [ad_conn instance_name]

# User
set user_id [ad_conn user_id]
set untrusted_user_id [ad_conn untrusted_user_id]
if { $untrusted_user_id != 0 } {
    set user_name [person::name -person_id $untrusted_user_id]
    set logout_url [ad_get_logout_url]
} 
if { $untrusted_user_id == 0 } {
    set login_url [ad_get_login_url -return]
}

set place /site-map/dashboard/

# Find current page
set url [ad_conn extra_url]

# Add trailing 'index', if necessary
if { [string match "*/" "/$url"] } {
    append url "index"
}

# TODO: Context bar
set context [list foo]

set current_folder [lindex [split $url /] 0]

multirow create navigation navtype label url link_title selected_p

foreach child [dotkul::get_metadata $place] {
    multirow append navigation \
        [dotkul::get_metadata $place$child.navtype] \
        [dotkul::get_metadata $place$child.label] \
        [ad_conn package_url]$child/ \
        [dotkul::get_metadata $place$child.link_title] \
        [string equal $current_folder $child]
}


