ad_page_contract {
    Generic add/edit page for object.

    @cvs-id $Id$
}

#----------------------------------------------------------------------
# Page Element Parameters
#----------------------------------------------------------------------
# We will want this to be handled by an ad_page_element_contract type construct

# parameters:
#  formspec
#  parent_id

array set params [list]
foreach { key value } $parameters {
    # LARS: Ugly and dangerous with the subst here
    set params($key) [subst $value]
}

# TODO: Get current values

# TODO: If form contains an upload element, set -html { enctype multipart/form-data }


ad_form -name generic_form -form [list [dotkul::get_metadata $params(formspec).key]:key]

#----------------------------------------------------------------------
# Add form elements
#----------------------------------------------------------------------

foreach element [dotkul::get_metadata $params(formspec)/] {

    set elm_name elm__$element

    # Get metadata

    set elm_form_mode [dotkul::get_metadata $params(formspec)/$element.form_mode]

    if { ![string equal $elm_form_mode "none"] } {
        
        set $elm_name [dotkul::get_metadata $params(formspec)/$element.default_value]
        set elm_datatype [dotkul::get_metadata $params(formspec)/$element.datatype]
        set elm_widget [dotkul::get_metadata $params(formspec)/$element.widget]
        set elm_required_p [dotkul::get_metadata -default 0 $params(formspec)/$element.required_p]
        set elm_label [dotkul::get_metadata $params(formspec)/$element.label]
        
        # Construct ad_form element declaration
        
        set elm_decl "${elm_name}:${elm_datatype}($elm_widget)"
        if { !$elm_required_p } {
            append elm_decl ",optional"
        }
        
        # Add element to ad_form
        
        ad_form -extend -name generic_form -form \
            [list [concat [list $elm_decl [list label \$elm_label]]]]
    }
}

#---------------------------------------------------------------------
# Add action handlers to the form definition
#---------------------------------------------------------------------

ad_form -extend -name generic_form -new_data {
    
    set entity [dotkul::get_metadata $params(formspec).entity]
    set storage [dotkul::get_metadata /entities/$entity.storage]
    
    array set values [list]

    foreach element [dotkul::get_metadata $params(formspec)/] {
        if { ![string equal [dotkul::get_metadata $params(formspec)/$element.form_mode] "none"] } {
            set elm_name elm__$element
            set values($element) [set $elm_name]
        }
    }

    set key [dotkul::storage::${storage}::new \
                 -key [set [dotkul::get_metadata $params(formspec).key]] \
                 -parent_id $params(parent_id) \
                 -entity $entity \
                 -array values]
}
