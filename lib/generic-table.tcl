#----------------------------------------------------------------------
# Page Element Parameters
#----------------------------------------------------------------------
# We will want this to be handled by an ad_page_element_contract type construct

# parameters:
#  entity
#  parent_id

if { [info exists parameters] } {
    array set params [list]
    foreach { key value } $parameters {
        # LARS: Ugly and dangerous with the subst here
        set params($key) [subst $value]
    }
} else {
    foreach key { entity parent_id } {
        if { [info exists $key] } {
            set params($key) [set $key]
        } else {
            set params($key) {}
        }
    }
}

     

set storage [dotkul::get_metadata $params(entity).storage]

switch $storage {
    content_item {
        set select [list]

        foreach attribute_path [dotkul::get_metadata $params(entity).all_attributes] {
            lappend select [dotkul::get_metadata $attribute_path.attribute_name]
        }

        set from [list [dotkul::get_metadata $params(entity).full_view]]

        set parent_id $params(parent_id)
        set where [list "parent_id = :parent_id"]

        set query "select [join $select ", "] from [join $from ", "] where [join $where " and "]"
    }
    default {
        error "Storage type '$storage' not implemented"
    }
}


db_multirow generic_list generic_list $query

template::list::create \
    -name generic_list \
    -elements {
        title {
            label "Title"
        }
    }
