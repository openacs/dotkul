set place [parameter::get -parameter PlaceReference]

# Find current page
set url [ad_conn extra_url]
# Add trailing 'index', if necessary
if { [string match "*/" "/$url"] } {
    set page ${place}${url}index
} else {
    set page ${place}${url}
}

set title [dotkul::get_metadata $page.title]

# TODO
set context [list $title]

multirow create page_elements src parameters title layout_tag

foreach element [dotkul::get_metadata $page/] {

    set page_element_ref [dotkul::get_metadata $page/$element.page-element]

    set src [dotkul::get_metadata $page_element_ref.src]

    set params [list]
    foreach param_name [dotkul::get_metadata $page/$element/] {
        lappend params $param_name [subst [dotkul::get_metadata $page/$element/$param_name.value]]
    }

    multirow append page_elements $src $params [dotkul::get_metadata $page/$element.title] [dotkul::get_metadata $page/$element.layout_tag]
}

set layout_template [dotkul::get_metadata $page.layout_template]
if { ![empty_string_p $layout_template] } {
    ad_return_template $layout_template
}
