#----------------------------------------------------------------------
# Page Element Parameters
#----------------------------------------------------------------------
# We will want this to be handled by an ad_page_element_contract type construct

# parameters:
#  target

array set params [list]
foreach { key value } $parameters {
    # LARS: Ugly and dangerous with the subst here
    set params($key) [subst $value]
}

# Hack ...
set url [ad_conn package_url][string range $params(target) [string length [parameter::get -parameter PlaceReference]] end]

set label [dotkul::get_metadata $params(target).title]
