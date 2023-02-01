# frozen_string_literal: true

json.coverage_badge_url coverage_img
json.coverage_badge_href coverage_href
json.issues_badge_url issues_img
json.issues_badge_href issues_href

json.templates do
  json.html do
    json.coverage <<~HTML
      <a href="#{coverage_href}"><img src="#{coverage_img}" /></a>
    HTML
    json.issues <<~HTML
      <a href="#{issues_href}"><img src="#{issues_img}" /></a>
    HTML
  end

  json.markdown do
    json.coverage <<~MD
      [![Coverage](#{coverage_img})](#{coverage_href})
    MD
    json.issues <<~MD
      [![Issues](#{issues_img})](#{issues_href})
    MD
  end

  json.textile do
    json.coverage <<~TEXTILE
      "!#{coverage_img}!":#{coverage_href}
    TEXTILE
    json.issues <<~TEXTILE
      "!#{issues_img}!":#{issues_href}
    TEXTILE
  end

  json.rdoc do
    json.coverage <<~RDOC
      {<img src="#{coverage_img}" />}[#{coverage_href}]
    RDOC
    json.issues <<~RDOC
      {<img src="#{issues_img}" />}[#{issues_href}]
    RDOC
  end

  json.restructured do
    json.coverage <<~RESTRUCTURED
      .. image:: #{coverage_img}
       :target: #{coverage_href}
       :alt: Coverage
    RESTRUCTURED
    json.issues <<~RESTRUCTURED
      .. image:: #{issues_img}
       :target: #{issues_href}
       :alt: Issues
    RESTRUCTURED
  end
end
