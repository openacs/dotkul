ad_library {
    API for creating, getting, editing, and deleting objects.
}

namespace eval object {}
namespace eval storage::acs_object {}
namespace eval storage::content_item {}

ad_proc -public storage::acs_object::get_list {
    -object_type:required
    {-filters {}}
    {-limit {}}
    {-offset {}}
    {-orderby {}}
} {
    Returns a multirow of objects
} {
    # Built assuming that the attributes will have no name conflicts

    set select [dotkul::get_metadata /object-types/$object_type.query_select]
    set from [dotkul::get_metadata /object-types/$object_type.query_from]
    set where [dotkul::get_metadata /object-types/$object_type.query_where]
    
    if { [empty_string_p $orderby] } {
        set orderby [dotkul::get_metadata /object-types/$object_type.query_orderby]
    }

    # References
    # TODO: We can get smarter about which attributes are really required, and avoid a number of joins that way
    # Maybe the referencing object decide which attributes of the referenced object are interesting,
    # or the referenced object has a set of attributes typically used for presentation (maybe using Branimir's
    # presentation trick, so we always only have to query acs_objects when referencing other objects,
    # unless you specifically mention them in the params to this proc)

    foreach attribute_ref [dotkul::get_metadata /object-types/$object_type.all_attributes] {
        set referencing_attribute_name [dotkul::get_metadata $attribute_ref.attribute_name]
        set referencing_table_name [dotkul::get_metadata $attribute_ref.table_name]
        set referencing_column_name [dotkul::get_metadata $attribute_ref.column_name]

        set references [dotkul::get_metadata $attribute_ref.references]
        if { ![empty_string_p $references] } {
            # Add to query
            
            # select creation_user__person.first_names as creation_user_first_names
            # from   persons creation_user__person
            # where  creation_user__person.person_id = acs_objects.creation_user

            set ref_tables [list]

            foreach referenced_attribute_ref [dotkul::get_metadata /object-types/$references.all_attributes] {
                set referenced_object_type [lindex [split $referenced_attribute_ref /] 2]
                set table_name [dotkul::get_metadata /object-types/$referenced_object_type.table_name]
                if { [lsearch $ref_tables $table_name] == -1 } {
                    lappend ref_tables $table_name
                    lappend from "$table_name ${referencing_attribute_name}__$table_name"

                    set id_column [dotkul::get_metadata /object-types/$referenced_object_type.id_column]

                    lappend where "${referencing_attribute_name}__$table_name.$id_column = $referencing_table_name.$referencing_column_name"
                }
                set referenced_column_name [dotkul::get_metadata $referenced_attribute_ref.column_name]
                lappend select "${referencing_attribute_name}__$table_name.$referenced_column_name as ${referencing_attribute_name}__$referenced_column_name"
            }
        }
    }

    # TODO: Filters
    
    

    # TODO: Categories

    set query "
select [join $select ",\n       "]
from   [join $from ",\n       "]
where  [join $where "\nand    "]
order  by $orderby
[ad_decode $limit {} {} "limit $limit"]
[ad_decode $offset {} {} "offset $offset"]
    "

    ds_comment $query
    
    db_multirow $object_type generated $query
}

ad_proc -public storage::acs_object::create_attribute {
    object_type attribute_name spec
} {
    Create new content type.
} {
    array set spec_array $spec
    
    foreach var { pretty_name pretty_plural default_value min_n_values max_n_values } {
        set $var $spec_array($var)
    }

    # TODO: Fixme
    db_exec_plsql object_type_create {
        select acs_attribute__create_attribute (
            :content_type,
            :attribute_name,
            :datatype,
            :pretty_name,
            :pretty_plural,
            null,
            null,
            :default_value,
            :min_n_values,
            :max_n_values,
            null,
            'generic',
            'f'
        )
    }
}

#----------------------------------------------------------------------
# content_item storage procs
#----------------------------------------------------------------------

ad_proc -public storage::content_item::new {
    -key:required
    -parent_id:required
    -entity:required
    -array:required
} {
    upvar 1 $array values

    if { ![exists_and_not_null values(name)] } {
        if { ![exists_and_not_null values(title)] } {
            error "You must supply a title"
        }
        
        set values(name) [util_text_to_url -text $values(title)]
    }
    if { ![exists_and_not_null values(mime_type)] } {
        set values(mime_type) "text/plain"
    }
    if { ![exists_and_not_null values(content_text)] } {
        set values(content_text) {}
    }
    if { ![exists_and_not_null values(description)] } {
        set values(description) {}
    }

    db_transaction {
        set item_id [bcms::item::create_item \
                         -item_id $key \
                         -item_name $values(name) \
                         -parent_id $parent_id \
                         -content_type $entity \
                         -storage_type "text"]
        
        # TODO: Actually put in attributes here!!!
        set attributes {}

        set revision_id [bcms::revision::add_revision \
                             -item_id $item_id \
                             -title $values(title) \
                             -content_type $entity \
                             -mime_type $values(mime_type) \
                             -content $values(content_text) \
                             -description $values(description) \
                             -additional_properties $attributes]

        
        bcms::revision::set_revision_status \
            -revision_id $revision_id \
            -status "live"
    }

    return $item_id
}

ad_proc -public storage::content_item::create_type {
    object_type spec
} {
    Create new content type.
} {
    array set spec_array $spec
    
    if { ![exists_and_not_null spec_array(extends)] } {
        set spec_array(extends) "content_revision"
    }
    foreach var { extends pretty_name pretty_plural table_name id_column } {
        set $var $spec_array($var)
    }

    db_exec_plsql object_type_create {
        select content_type__create_type (
            :object_type,
            :extends,
            :pretty_name,
            :pretty_plural,
            :table_name,
            :id_column,
            null
        )
    }
}

ad_proc -public storage::content_item::create_attribute {
    object_type attribute_name spec
} {
    Create new content type.
} {
    array set spec_array $spec
    
    foreach var { pretty_name pretty_plural default_value min_n_values max_n_values } {
        set $var $spec_array($var)
    }

    db_exec_plsql attribute_create {
        select content_type__create_attribute (
            :object_type,
            :attribute_name,
            :datatype,
            :pretty_name,
            :pretty_plural,
            null,
            :default_value,
            :column_spec XXXX
        );
    }
}



#----------------------------------------------------------------------
# Procs for defining object types
#----------------------------------------------------------------------

ad_proc -public object::define_type { object_type spec } { 
    Declare new object types
} {
    array set spec_array $spec

    # Guess properties
    if { ![exists_and_not_null spec_array(pretty_name)] } {
        set spec_array(pretty_name) [string totitle [string map {_ } $object_type]]
    }
    if { ![exists_and_not_null spec_array(pretty_plural)] } {
        set spec_array(pretty_plural) "$spec_array(pretty_name)s"
    }
    if { ![exists_and_not_null spec_array(table_name)] } {
        set spec_array(table_name) "${object_type}s"
    }
    if { ![exists_and_not_null spec_array(id_column)] } {
        set spec_array(id_column) "${object_type}_id"
    }
    if { ![exists_and_not_null spec_array(storage)] } {
        if { [exists_and_not_null spec_array(extends)] } {
            set spec_array(storage) [dotkul::get_metadata /object-types/$extends.storage]
        } else {
            set spec_array(storage) "acs_object"
        }
    }

    if { [exists_and_not_null spec_array(attributes)] } {
        set attributes $spec_array(attributes)
        unset spec_array(attributes)
    } else {
        set attributes {}
    }

    if { [empty_string_p [dotkul::get_metadata /object-types/$object_type.type]] } {
        # Object type doesn't already exist, create
        
            storage::$spec_array(storage)::create_type $object_type [array get spec_array]
        }
    } else {
        # Update metadata in memory
        foreach { property value } [array get spec_array] {
            dotkul::set_metadata /object-types/$object_type.$property $value
        }
        # TODO: Update metadata about object-type in DB
    }


    foreach { attribute_name attribute_spec } $attributes {
        array set attribute_spec_aray $attribute_spec
        
        if { ![exists_and_not_null attribute_spec_array(pretty_name)] } {
            set attribute_spec_array(pretty_name) [string totitle [string map {_ } $attribute_name]]
        }
        if { ![exists_and_not_null attribute_spec_array(pretty_plural)] } {
            set attribute_spec_array(pretty_plural) "$attribute_spec_array(pretty_name)s"
        }
        if { ![exists_and_not_null attribute_spec_array(column_name)] } {
            set attribute_spec_array(column_name) $attribute_name
        }
        if { ![exists_and_not_null attribute_spec_array(datatype)] } {
            set attribute_spec_array(datatype) "string"
        }
        if { ![exists_and_not_null attribute_spec_array(default_value)] } {
            set attribute_spec_array(default_value) ""
        }
        if { ![exists_and_not_null attribute_spec_array(min_n_values)] } {
            set attribute_spec_array(min_n_values) 0
        }
        if { ![exists_and_not_null attribute_spec_array(max_n_values)] } {
            set attribute_spec_array(max_n_values) 1
        }

        if { ![empty_string_p [dotkul::get_metadata /object-types/$object_type/$attribute_name.type]] } {
            # New attribute
            storage::$spec_array(storage)::create_attribute $object_type $attribute_name [array get attribute_spec_array]
        } else {
            # Update metadata in memory
            foreach { property value } [array get attribute_spec_array] {
                dotkul::set_metadata /object-types/$object_type/$attribute_name.$property $value
            }
            # TODO: Update metadata about attribute in DB
        }
    }
}


#----------------------------------------------------------------------
# Define some core object types
#----------------------------------------------------------------------

object::define_type acs_object {
    attributes {
        creation_user {
            references user
        }
    }
}

object::define_type users {
    attributes {
        presentation {
            eval {
                $first_names $last_name
            }
        }
    }
}
