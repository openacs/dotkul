<div class="Left">

  <multiple name="page_elements">
    <if @page_elements.layout_tag@ eq "left">
      <include-optional src="@page_elements.src@" parameters="@page_elements.parameters@">
        <div class="SectionHeader">
          <h1>@page_elements.title@</h1>
          <include-output>
        </div>
      </include-optional>
    </if>
  </multiple>

</div>

<div class="Right">
  <div class="Sidebar">

    <multiple name="page_elements">
      <if @page_elements.layout_tag@ eq "right">
        <include-optional src="@page_elements.src@" parameters="@page_elements.parameters@">
          <div class="SectionHeader">
            <h1>@page_elements.title@</h1>
            <include-output>
          </div>
        </include-optional>
      </if>
    </multiple>

  </div>
</div>
