<master src="/www/blank-master">
  <if @title@ not nil>
    <property name="title">@title;noquote@</property>
  </if>
  <if @signatory@ not nil>
    <property name="signatory">@signatory;noquote@</property>
  </if>
  <if @focus@ not nil>
    <property name="focus">@focus;noquote@</property>
  </if>
  <property name="header_stuff">
    <link rel="Stylesheet" href="/resources/dotkul/cnet.css" type="text/css" media="screen" />
    <style>
a:link, a:visited {
color: #03c;
}

a:hover {
color: #fff;
background-color: #03c;
}

#Header {
background-color: #036;
}

#Header h1 {
color: #fc0;
}

#Header h3, #Header h3 a:link, #Header h3 a:visited {
color: #fff;
}

#Header h3 a:hover {
color: #000;
background-color: #ffc;
}

#Header h3 a.current:link, #Header h3 a.current:visited {
color: #fc0;
}

#Header h3 a.current:hover {
color: #fc0;
background-color: #036;
}

#Header h1 a:link, #Header h1 a:visited {
color: #fc0;
text-decoration: none;
}

#Header h1 a:hover {
color: #fc0;
background-color: #036;
text-decoration: underline;
}

#Header h2 {
color: #fff;
}

#Header h2 a:link, #Header h2 a:visited {
color: #fff;
text-decoration: none;
}

#Header h2 a:hover {
color: #fff;
background-color: #036;
text-decoration: underline;
}


#Tabs a:link, #Tabs a:visited {
background-color: #eaeac7;
color: #333;
border: 1px solid #036;
border-bottom: 1px solid #eaeac7;
}

#Tabs a:link.current, #Tabs a:visited.current {
color: #393;
}

#Tabs a:hover {
color: #000;
background-color: #ffc;
border-bottom: 1px solid #ffc;
}

#Tabs li#AdminTab a:link, #Tabs li#AdminTab a:visited {
color: #fff;
background-color: #036;
border-bottom: 1px solid #036;
text-decoration: underline;
}

#Tabs li#AdminTab a:hover {
color: #fc0;
}

#Tabs li#AdminTab a.current {
color: #fc0;
text-decoration: none;
}
    </style>
    <script language="JavaScript" type="text/javascript" src="/resources/dotkul/cnet.js"></script>
    @header_stuff;noquote@
  </property>

<div id="StatusBarContainer">


<div id="Statusbar">
 <div id="StatusLeft">
 @account_name@
  </div>

   <div id="StatusRight">
     Logged in as @user_name@ (<a href="@logout_url@" title="Log-out and clear the cookie off your machine">Log-out</a>)
      </div>
      </div>
</div>

<div class="Shadow">
<div class="Container">

<div id="Header">

 
  <h3>
    <multiple name="navigation">
      <group column="navtype">
        <if @navigation.navtype@ eq "side">
          <if @navigation.groupnum@ gt 1>|</if>
          <if @navigation.selected_p@ true>
            <a href="@navigation.url@" title="@navigation.link_title@" class="current">@navigation.label@</a>
          </if>
          <else>
            <a href="@navigation.url@" title="@navigation.link_title@">@navigation.label@</a>
          </else>
        </if>
        </if>
      </group>
    </multiple>
  </h3>
     
      <h1 style="padding-bottom: 7px;">Dashboard</h1>
      
      <ul id="Tabs">
        <multiple name="navigation">
          <group column="navtype">
            <if @navigation.navtype@ eq "main">
              <if @navigation.selected_p@ true>
                <li><a href="@navigation.url@" title="@navigation.link_title@" class="current">@navigation.label@</a></li>
              </if>
              <else>
                <li><a href="@navigation.url@" title="@navigation.link_title@">@navigation.label@</a></li>
              </else>
            </if>
          </group>
        </multiple>
     </ul>
   </div>
 <div id="DashContentFrame">
 
 <slave>

</div>
</div>

<div class="ShadowCap">&nbsp;</div>
</div>

<div id="Footer">
  Footer stuff
</div>

