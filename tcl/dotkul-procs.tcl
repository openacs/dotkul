namespace eval dotkul {}
namespace eval dotkul::storage {}
namespace eval dotkul::storage::content_item {}



# HACK: Unset everything
if { [nsv_array exists acs_metadata] } {
    nsv_unset acs_metadata
}


#----------------------------------------------------------------------
# Accessor for metadata
#----------------------------------------------------------------------

# Define a helper proc to make it easier to get metadata properties
ad_proc dotkul::get_metadata {
    {-default ""}
    path
} {
    Get a metadata property
} {
    if { [nsv_exists acs_metadata $path] } {
        return [nsv_get acs_metadata $path]
    } else {
        return $default
    }
}

ad_proc dotkul::get_node_type {
    {-default ""}
    path
} {
    return [dotkul::get_metadata $path.type]
}

ad_proc dotkul::get_property_type {
    {-default ""}
    node_type
    property
} {
    return [dotkul::get_metadata "/system/metadata/node-types/$node_type/$property.property_type"]
}

ad_proc dotkul::get_node_properties {
    {-default ""}
    path
} {
    returns a list of { property1 value1 property2 value2 ... }
} {
    set result [list]
    foreach property_path [lsort [nsv_array names acs_metadata "$path.*"]] {
        set property [lindex [split $property_path .] 1]
        if { ![string equal $property "type"] } {
            lappend result $property
            lappend result [dotkul::get_metadata $property_path]
        }
    }
    return $result
}

ad_proc dotkul::get_node_children {
    {-default ""}
    path
} {
    if { ![string equal [string index $path end] /] } {
        append path /
    }
    set children [dotkul::get_metadata $path]
    return $children
}

ad_proc dotkul::set_metadata {
    path
    value
} {
    Set a metadata property
} {
    if { [string first . $path] == -1 } {
        error "Invalid path '$path'. Path must be on the form /path/to/object.property."
    }
    nsv_set acs_metadata $path $value

    # path = /site-map/dashboard/projects/project-add/form.title

    set path [file rootname $path]
    # path = /site-map/dashboard/projects/project-add/form

    while { 1 } {
        set tail [file tail $path]
        if { [empty_string_p $tail] } {
            break
        }
        set path [file dirname $path]
        #ns_log Notice "path=$path, tail=$tail"

        # tail = form
        # path = /site-map/dashboard/projects/project-add

        if { [nsv_exists acs_metadata $path/$tail] } {
            #ns_log Notice "Entry exists for $path/$tail"
            # A property already exists here, so that node's index has already been created
            break
        }
        nsv_lappend acs_metadata [string trimright $path /]/ $tail
        nsv_set acs_metadata $path/$tail {}
    }
}


#----------------------------------------------------------------------
# Page Element Contract
#----------------------------------------------------------------------

ad_proc -public ad_page_element_contract {
    args
} {
    upvar 1 parameters parameters

    set form [ns_set create]

    if { [info exists parameters] } {
        foreach { key value } $parameters {
            ns_set put $form $key $value
        }
    }

    uplevel ad_page_contract -form $form $args
    ns_set free $form
}







#----------------------------------------------------------------------
# Object-Type types (object types, content types, tables)
#----------------------------------------------------------------------

# nsv_set acs_metadata /object-types/ { post }
# nsv_set acs_metadata /object-types/post.storage "content_item"
# nsv_set acs_metadata /object-types/post.content_type "post"
# nsv_set acs_metadata /object-types/post.pretty_name "Post"
# nsv_set acs_metadata /object-types/post/ { extended_message }
# nsv_set acs_metadata /object-types/post/extended_message.pretty_name "Extended Message"

ad_proc dotkul::build_object_type_metadata {} {
    Build nsv data structure for object-types
} {
    db_foreach object_types {
        select object_type, supertype, pretty_name, pretty_plural, table_name, id_column, 
               package_name, name_method, type_extension_table
        from   acs_object_types
        order  by tree_sortkey
    } {

        dotkul::set_metadata /object-types/$object_type.type object_type
        dotkul::set_metadata /object-types/$object_type.storage "acs_object"

        foreach col { 
            object_type supertype pretty_name pretty_plural table_name id_column
            package_name name_method type_extension_table
        } {
            dotkul::set_metadata /object-types/$object_type.$col [set $col]
        }
        dotkul::set_metadata /object-types/$object_type.all_attributes [list]

        # Clear out stuff which would otherwise hurt us of this proc is run multiple times
        foreach property { all_attributes query_where query_from query_select } {
            nsv_set acs_metadata /object-types/$object_type.$property {}
        }
    }

    #----------------------------------------------------------------------
    # Generate the type hierarchy
    #----------------------------------------------------------------------
    
    foreach object_type [dotkul::get_metadata /object-types/] {

        set supertypes $object_type
        
        set last_supertype $object_type
        set supertype [dotkul::get_metadata /object-types/$object_type.supertype]
        while { ![string equal $supertype $last_supertype] && ![empty_string_p $supertype] } {
            set supertypes [concat $supertype $supertypes]
            set last_supertype $supertype
            set supertype [dotkul::get_metadata /object-types/$supertype.supertype]
        }

        dotkul::set_metadata /object-types/$object_type.supertype_list $supertypes

        if { [lsearch -exact $supertypes "content_revision"] != -1 } {
            dotkul::set_metadata /object-types/$object_type.storage "content_item"
            dotkul::set_metadata /object-types/$object_type.full_view "[dotkul::get_metadata /object-types/$object_type.table_name]x"
        }
    }

    #----------------------------------------------------------------------
    # Add attributes
    #----------------------------------------------------------------------

    # Mapping from acs_attributes datatype to formbuilder datatypes
    array set form_datatype {
        string text
        boolean text
        number text
        integer integer
        money text
        date text
        timestamp text
        time_of_day text
        enumeration text
        url text
        email text
        text text
        keyword integer
    }

    # Mapping from acs_attributes datatype to default formbuilder widgets
    array set form_widget {
        string text
        boolean radio
        number text
        integer text
        money text
        date text
        timestamp text
        time_of_day text
        enumeration text
        url text
        email text
        text textarea
        keyword integer
    }

    # Default options
    array set form_options {
        string {}
        boolean { 
            { {Yes t} {No f} }
        }
        number {}
        integer {}
        money {}
        date {}
        timestamp {}
        time_of_day {}
        enumeration {}
        url {}
        email {}
        text {}
        keyword {}
    }

    # Get object attributes
    db_foreach select_attributes {
        select object_type, table_name, attribute_name, pretty_name, pretty_plural, datatype, 
               default_value, min_n_values, storage, static_p, column_name
        from   acs_attributes
        where  storage = 'type_specific'
        and    static_p = 'f'
        order  by object_type, sort_order
    } {
        dotkul::set_metadata /object-types/$object_type/$attribute_name.type attribute
        foreach col {
            table_name attribute_name pretty_name pretty_plural datatype 
            default_value min_n_values storage static_p column_name
        } {
            dotkul::set_metadata /object-types/$object_type/$attribute_name.$col [set $col]
        }

        if { [empty_string_p $table_name] } {
            dotkul::set_metadata /object-types/$object_type/$attribute_name.table_name [dotkul::get_metadata /object-types/$object_type.table_name]
        }
        if { [empty_string_p $column_name] } {
            dotkul::set_metadata /object-types/$object_type/$attribute_name.column_name $attribute_name
        }

        # Special form-builder presentation options
        dotkul::set_metadata /object-types/$object_type/$attribute_name.form_datatype $form_datatype($datatype)
        dotkul::set_metadata /object-types/$object_type/$attribute_name.form_widget $form_widget($datatype)
        dotkul::set_metadata /object-types/$object_type/$attribute_name.form_options $form_options($datatype)
    }

    #----------------------------------------------------------------------
    # Add inherited attributes, plus query to get the full object
    #----------------------------------------------------------------------

    # Add parent attributes to child types
    foreach object_type [dotkul::get_metadata /object-types/] {
        set last_supertype {}
        foreach supertype [dotkul::get_metadata /object-types/$object_type.supertype_list] {
            if { ![empty_string_p $last_supertype] } {
                set where "[dotkul::get_metadata /object-types/$last_supertype.table_name].[dotkul::get_metadata /object-types/$last_supertype.id_column] = [dotkul::get_metadata /object-types/$supertype.table_name].[dotkul::get_metadata /object-types/$supertype.id_column]"
                nsv_lappend acs_metadata /object-types/$object_type.query_where $where
            }
            set last_supertype $supertype
            foreach attribute [dotkul::get_metadata /object-types/$supertype/] {
                nsv_lappend acs_metadata /object-types/$object_type.all_attributes /object-types/$supertype/$attribute

                set table_name [dotkul::get_metadata /object-types/$supertype/$attribute.table_name]
                if { [lsearch [dotkul::get_metadata /object-types/$object_type.query_from] $table_name] == -1 } {
                    nsv_lappend acs_metadata /object-types/$object_type.query_from $table_name
                }
                nsv_lappend acs_metadata /object-types/$object_type.query_select $table_name.$attribute
            }
        }
    }
}

# HACK
dotkul::build_object_type_metadata

#----------------------------------------------------------------------
# Override stuff - prototyping
#----------------------------------------------------------------------

dotkul::set_metadata /object-types/acs_object/object_type.form_mode none
dotkul::set_metadata /object-types/acs_object/creation_date.form_mode none
dotkul::set_metadata /object-types/acs_object/creation_ip.form_mode none
dotkul::set_metadata /object-types/acs_object/creation_user.form_mode none
dotkul::set_metadata /object-types/acs_object/last_modified.form_mode none
dotkul::set_metadata /object-types/acs_object/modifying_ip.form_mode none
dotkul::set_metadata /object-types/acs_object/creation_ip.form_mode none
dotkul::set_metadata /object-types/acs_object/context_id.form_mode none


dotkul::set_metadata /object-types/content_revision/title.datatype string
dotkul::set_metadata /object-types/content_revision/title.form_widget text

dotkul::set_metadata /object-types/pinds_blog_entry.query_orderby "entry_date desc"



#----------------------------------------------------------------------
# Foreign keys
#----------------------------------------------------------------------

dotkul::set_metadata /object-types/acs_object/creation_user.references user



#----------------------------------------------------------------------
# Forms
#----------------------------------------------------------------------

# dotkul::set_metadata /formspecs/ { post }

# dotkul::set_metadata /formspecs/post/ { title content extended_message }

# dotkul::set_metadata /formspecs/post.key item_id

# dotkul::set_metadata /formspecs/post/title.entity post
# dotkul::set_metadata /formspecs/post/title.attribute title
# dotkul::set_metadata /formspecs/post/title.label "Title"
# dotkul::set_metadata /formspecs/post/title.widget "text"
# dotkul::set_metadata /formspecs/post/title.datatype "text"
# dotkul::set_metadata /formspecs/post/title.options {}
# dotkul::set_metadata /formspecs/post/title.help_text "This will show up at the top of your post"

# dotkul::set_metadata /formspecs/post/content.label "Message"

# dotkul::set_metadata /formspecs/post/extended_message.label "Extended Message"

ad_proc dotkul::build_form_metadata {} {
    Build nsv data structure for forms
} {
    foreach entity [dotkul::get_metadata /object-types/] {
        dotkul::set_metadata /formspecs/$entity.type formspec

        switch [dotkul::get_metadata /object-types/$entity.storage] {
            acs_object {
                dotkul::set_metadata /formspecs/$entity.key [dotkul::get_metadata /object-types/$entity.id_column]
            }
            content_item {
                dotkul::set_metadata /formspecs/$entity.key item_id
            }
        }
        dotkul::set_metadata /formspecs/$entity.entity $entity
        
        foreach supertype [dotkul::get_metadata /object-types/$entity.supertype_list] {
            foreach attribute [dotkul::get_metadata /object-types/$supertype/] {

                dotkul::set_metadata /formspecs/$entity/${attribute}.type formspec-element

                dotkul::set_metadata /formspecs/$entity/${attribute}.entity $supertype
                dotkul::set_metadata /formspecs/$entity/${attribute}.attribute $attribute

                dotkul::set_metadata /formspecs/$entity/${attribute}.label \
                    [dotkul::get_metadata /object-types/$supertype/$attribute.pretty_name]
                dotkul::set_metadata /formspecs/$entity/${attribute}.widget \
                    [dotkul::get_metadata /object-types/$supertype/$attribute.form_widget]
                dotkul::set_metadata /formspecs/$entity/${attribute}.datatype \
                    [dotkul::get_metadata /object-types/$supertype/$attribute.form_datatype]
                dotkul::set_metadata /formspecs/$entity/${attribute}.options \
                    [dotkul::get_metadata /object-types/$supertype/$attribute.form_options]
                dotkul::set_metadata /formspecs/$entity/${attribute}.form_mode \
                    [dotkul::get_metadata /object-types/$supertype/$attribute.form_mode]
            }
        }
    }

    #----------------------------------------------------------------------
    # Override stuff - prototyping
    #----------------------------------------------------------------------
    
    dotkul::set_metadata /formspecs/project/nls_language.form_mode none
    dotkul::set_metadata /formspecs/project/description.form_mode none
    dotkul::set_metadata /formspecs/project/mime_type.form_mode none
    dotkul::set_metadata /formspecs/project/publish_date.form_mode none
}

# HACK
dotkul::build_form_metadata




















#----------------------------------------------------------------------
# Node and property types
#----------------------------------------------------------------------

dotkul::set_metadata /system/metadata/node-types/object_type.type metadata_node
dotkul::set_metadata /system/metadata/node-types/object_type/all_attributes.type metadata_property
dotkul::set_metadata /system/metadata/node-types/object_type/all_attributes.property_type metadata_reference_list

dotkul::set_metadata /system/metadata/node-types/page-element-instance.type metadata_node
dotkul::set_metadata /system/metadata/node-types/page-element-instance/page-element.type metadata_property
dotkul::set_metadata /system/metadata/node-types/page-element-instance/page-element.property_type metadata_reference







#----------------------------------------------------------------------
# Page elements
#----------------------------------------------------------------------

dotkul::set_metadata /page-elements/generic-table.type page-element
dotkul::set_metadata /page-elements/generic-table.src "/packages/dotkul/lib/generic-table"
dotkul::set_metadata /page-elements/generic-table/entity.type parameter
dotkul::set_metadata /page-elements/generic-table/entity.datatype metadata
dotkul::set_metadata /page-elements/generic-table/entity.metadata_root /object-types/
dotkul::set_metadata /page-elements/generic-table/parent_id.type parameter
dotkul::set_metadata /page-elements/generic-table/parent_id.datatype object_id
dotkul::set_metadata /page-elements/generic-table/parent_id.object_supertype acs_object



dotkul::set_metadata /page-elements/generic-form.type page-element
dotkul::set_metadata /page-elements/generic-form.src "/packages/dotkul/lib/generic-form"
dotkul::set_metadata /page-elements/generic-form/formspec.type parameter
dotkul::set_metadata /page-elements/generic-form/formspec.datatype metadata
dotkul::set_metadata /page-elements/generic-form/formspec.metadata_root /formspecs/
dotkul::set_metadata /page-elements/generic-form/parent_id.type parameter
dotkul::set_metadata /page-elements/generic-form/parent_id.datatype object_id
dotkul::set_metadata /page-elements/generic-form/parent_id.supertype acs_object


dotkul::set_metadata /page-elements/generic-link.type page-element
dotkul::set_metadata /page-elements/generic-link.src "/packages/dotkul/lib/generic-link"
dotkul::set_metadata /page-elements/generic-link/target.type parameter
dotkul::set_metadata /page-elements/generic-link/target.datatype metadata
dotkul::set_metadata /page-elements/generic-link/target.metadata_root /site-map/




#----------------------------------------------------------------------
# Blogger page elements
#----------------------------------------------------------------------

dotkul::set_metadata /page-elements/blog.type page-element
dotkul::set_metadata /page-elements/blog.src "/packages/lars-blogger/www/blog"
dotkul::set_metadata /page-elements/blog/package_id.type parameter
dotkul::set_metadata /page-elements/blog/package_id.datatype object_id
dotkul::set_metadata /page-elements/blog/package_id.supertype acs_object
dotkul::set_metadata /page-elements/blog/package_id.required_p t

dotkul::set_metadata /page-elements/blog/template.type parameter
dotkul::set_metadata /page-elements/blog/template.datatype ats_template
dotkul::set_metadata /page-elements/blog/template.required_p f

dotkul::set_metadata /page-elements/blog/max_num_entries.type parameter
dotkul::set_metadata /page-elements/blog/max_num_entries.datatype integer
dotkul::set_metadata /page-elements/blog/min_num_entries.type parameter
dotkul::set_metadata /page-elements/blog/min_num_entries.datatype integer
dotkul::set_metadata /page-elements/blog/num_days.type parameter
dotkul::set_metadata /page-elements/blog/num_days.datatype integer
dotkul::set_metadata /page-elements/blog/max_content_length.type parameter
dotkul::set_metadata /page-elements/blog/max_content_length.datatype integer
dotkul::set_metadata /page-elements/blog/permalink_page.type parameter
dotkul::set_metadata /page-elements/blog/permalink_page.datatype metadata
dotkul::set_metadata /page-elements/blog/permalink_page.metadata_root /site-map/

dotkul::set_metadata /page-elements/blog-calendar.type page-element
dotkul::set_metadata /page-elements/blog-calendar.src "/packages/lars-blogger/www/calendar"
dotkul::set_metadata /page-elements/blog-calendar/package_id.type parameter
dotkul::set_metadata /page-elements/blog-calendar/package_id.datatype object_id
dotkul::set_metadata /page-elements/blog-calendar/package_id.supertype acs_object
dotkul::set_metadata /page-elements/blog-calendar/package_id.required_p t

dotkul::set_metadata /page-elements/blog-entry.type page-element
dotkul::set_metadata /page-elements/blog-entry.src "/packages/lars-blogger/www/one-entry"
dotkul::set_metadata /page-elements/blog-entry/entry_id.type parameter
dotkul::set_metadata /page-elements/blog-entry/entry_id.datatype object_id
dotkul::set_metadata /page-elements/blog-entry/entry_id.supertype pinds_blog_entry
dotkul::set_metadata /page-elements/blog-entry/entry_id.required_p t










#----------------------------------------------------------------------
# Define dashboard pageflow
#----------------------------------------------------------------------


dotkul::set_metadata /site-map/dashboard.type place
dotkul::set_metadata /site-map/dashboard.label "Dashboard"
dotkul::set_metadata /site-map/dashboard.master "/packages/dotkul/lib/dashboard-master"

dotkul::set_metadata /site-map/dashboard/projects.type page-folder
dotkul::set_metadata /site-map/dashboard/projects.label "Projects"
dotkul::set_metadata /site-map/dashboard/projects.navtype main
dotkul::set_metadata /site-map/dashboard/projects.link_title "Overview over all clients and projects"

dotkul::set_metadata /site-map/dashboard/projects/index.type page
dotkul::set_metadata /site-map/dashboard/projects/index.title ""
dotkul::set_metadata /site-map/dashboard/projects/index.layout_template "/packages/dotkul/lib/dashboard-overview"

dotkul::set_metadata /site-map/dashboard/projects/index/project-list.type page-element-instance
dotkul::set_metadata /site-map/dashboard/projects/index/project-list.title "Your Projects"
dotkul::set_metadata /site-map/dashboard/projects/index/project-list.layout_tag left
dotkul::set_metadata /site-map/dashboard/projects/index/project-list.page-element /page-elements/generic-table
dotkul::set_metadata /site-map/dashboard/projects/index/project-list/entity.type parameter-value 
dotkul::set_metadata /site-map/dashboard/projects/index/project-list/entity.value /object-types/project
dotkul::set_metadata /site-map/dashboard/projects/index/project-list/parent_id.type parameter-value 
dotkul::set_metadata /site-map/dashboard/projects/index/project-list/parent_id.value {[ad_conn package_id]}

dotkul::set_metadata /site-map/dashboard/projects/index/project-add.type page-element-instance
dotkul::set_metadata /site-map/dashboard/projects/index/project-add.title "Create New Project"
dotkul::set_metadata /site-map/dashboard/projects/index/project-add.layout_tag right
dotkul::set_metadata /site-map/dashboard/projects/index/project-add.page-element /page-elements/generic-link
dotkul::set_metadata /site-map/dashboard/projects/index/project-add/target.type parameter-value 
dotkul::set_metadata /site-map/dashboard/projects/index/project-add/target.value /site-map/dashboard/projects/project-add

dotkul::set_metadata /site-map/dashboard/projects/project-add.type page
dotkul::set_metadata /site-map/dashboard/projects/project-add.title "Create Project"
dotkul::set_metadata /site-map/dashboard/projects/project-add/project-form.type page-element-instance
dotkul::set_metadata /site-map/dashboard/projects/project-add/project-form.page-element /page-elements/generic-form
dotkul::set_metadata /site-map/dashboard/projects/project-add/project-form/formspec.type parameter-value
dotkul::set_metadata /site-map/dashboard/projects/project-add/project-form/formspec.value /formspecs/project
dotkul::set_metadata /site-map/dashboard/projects/project-add/project-form/parent_id.type parameter-value
dotkul::set_metadata /site-map/dashboard/projects/project-add/project-form/parent_id.value {[ad_conn package_id]}



#----------------------------------------------------------------------
# Blogger pages
#----------------------------------------------------------------------

# HACK - I did it only so that metadata doesn't depend on database ids
# In order to use the blogger it has to be installed and one instance of it
# mounted at /weblogger/ That's the one we'll use.

set blogger_url "/weblogger/"
set package_key "lars-blogger"
array set site_node_arr [site_node::get -url $blogger_url]
set blogger_package_id $site_node_arr(package_id)

if {$site_node_arr(object_type)  != "apm_package" ||
    $site_node_arr(package_key) != $package_key} {
      error "Can't find an instance of $package_key mounted at $blogger_url"
}

dotkul::set_metadata /site-map/dashboard/blog.type page-folder
dotkul::set_metadata /site-map/dashboard/blog.label "Messages"
dotkul::set_metadata /site-map/dashboard/blog.navtype main

dotkul::set_metadata /site-map/dashboard/blog/index.type page
dotkul::set_metadata /site-map/dashboard/blog/index.layout_template "/packages/dotkul/lib/dashboard-overview"

dotkul::set_metadata /site-map/dashboard/blog/index/blog.type page-element-instance
dotkul::set_metadata /site-map/dashboard/blog/index/blog.title "All Messages"
dotkul::set_metadata /site-map/dashboard/blog/index/blog.page-element /page-elements/blog
dotkul::set_metadata /site-map/dashboard/blog/index/blog.layout_tag left
dotkul::set_metadata /site-map/dashboard/blog/index/blog/template.type parameter-value

# This is where you swap the template:
dotkul::set_metadata /site-map/dashboard/blog/index/blog/template.value /packages/lars-blogger/www/blog

dotkul::set_metadata /site-map/dashboard/blog/index/blog/package_id.type parameter-value 
dotkul::set_metadata /site-map/dashboard/blog/index/blog/package_id.value $blogger_package_id
dotkul::set_metadata /site-map/dashboard/blog/index/blog/comments_page.type parameter-value
dotkul::set_metadata /site-map/dashboard/blog/index/blog/comments_page.value /site-map/dashboard/blog/comments

dotkul::set_metadata /site-map/dashboard/blog/index/calendar.type page-element-instance
dotkul::set_metadata /site-map/dashboard/blog/index/calendar.title "Posting History"
dotkul::set_metadata /site-map/dashboard/blog/index/calendar.page-element /page-elements/blog-calendar
dotkul::set_metadata /site-map/dashboard/blog/index/calendar.layout_tag right
dotkul::set_metadata /site-map/dashboard/blog/index/calendar/package_id.type parameter-value 
dotkul::set_metadata /site-map/dashboard/blog/index/calendar/package_id.value $blogger_package_id


dotkul::set_metadata /site-map/dashboard/blog/comments.type page
dotkul::set_metadata /site-map/dashboard/blog/comments.title "TODO: Title of Entry"

dotkul::set_metadata /site-map/dashboard/blog/comments/blog-entry.type page-element-instance
dotkul::set_metadata /site-map/dashboard/blog/comments/blog-entry.page-element /page-elements/blog-entry
dotkul::set_metadata /site-map/dashboard/blog/comments/blog-entry/entry_id.type parameter-value
dotkul::set_metadata /site-map/dashboard/blog/comments/blog-entry/entry_id.source query
