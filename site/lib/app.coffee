# App's main client script
$       = require('jquery')
moment  = require('lib/moment')
require('lib/fastclick')

handlebars = require('handlebars')
settings  = require('settings/root')

exports.initialize = (config) ->
  # Use the fastclick module for touch devices.
  # Add a class of `needsclick` of the original click
  # is needed.
  new FastClick(document.body)

  setupNavMenus()
  setupSmoothScrolling()
  setupTimestampFormatting()
  setupClickTracking()


setupNavMenus = ->
  $mainNav = $('.main-nav')
  $mainNavIcon = $mainNav.find('> .icon')
  $mainNavList = $mainNav.find('> ul')
  $mainNavSearchInput = $mainNav.find('.search-box input')
  
  $searchResultsView = $('.search-results-view')
  $searchResultsInput = $searchResultsView.find('input')
  $searchResultsList = $searchResultsView.find('.list')
  $searchResultsCloseButton = $searchResultsView.find('.close-button')
  searchResults = {}
  
  $tocNav = $('.toc-nav')
  $tocNavIcon = $tocNav.find('> .icon')
  $tocNavList = $tocNav.find('> ul')
  
  $collectionNav = $('.collection-nav')
  $collectionNavIcon = $collectionNav.find('> .icon')
  $collectionNavList = $collectionNav.find('> ul')
  collectionDocs = []
  
  $articleView = $('.container > article.view')

  hidePopups = (exceptMe) ->
    unless $mainNavList is exceptMe
      $mainNavList.hide()
      $mainNavIcon.removeClass('open')
    unless $tocNavList is exceptMe
      $tocNavList.hide()
      $tocNavIcon.removeClass('open')
    unless $collectionNavList is exceptMe
      $collectionNavList.hide()
      $collectionNavIcon.removeClass('open')

  $('html').on 'click', (e) ->
    hidePopups()
  
  # Setup the Main menu
  $mainNavIcon.on 'click', (e) ->
    e.stopPropagation()
    hidePopups($mainNavList)
    $mainNavList.toggle()
    $mainNavIcon.toggleClass('open')
    _gaq?.push(['_trackEvent', 'Site Navigation', 'Click', 'Main Nav Icon'])

  $mainNavSearchInput.on 'click', (e) ->
    e.stopPropagation()
    _gaq?.push(['_trackEvent', 'Site Navigation', 'Click', 'Search Box'])

  $searchResultsCloseButton.on 'click', (e) ->
    # Close and reset search input fields
    $searchResultsView.hide()
    $searchResultsInput.val('')
    $mainNavSearchInput.val('')
    $searchResultsList.html('')

  performSearch = (e) ->
    e.stopPropagation()
    # Show search results on Enter key
    if e.which is 13
      $inputField = $(e.currentTarget)
      term = $.trim $inputField.val()
      if term
        hidePopups()
        $mainNavSearchInput.val(term)
        $searchResultsInput.val(term)
        document.activeElement.blur() # to hide mobile keyboard
        $searchResultsView.show()
        $searchResultsList.html('<li>Looking, please wait...</li>')

        site = $inputField.attr('data-site')
        query = encodeURIComponent("site:#{site} AND (#{term})")
        
        $.ajax
          type: 'GET'
          url: "/json/search?q=#{query}"
          contentType: 'json'
          success: (data) ->
            if data
              data = JSON.parse(data)
              $searchResultsList.html("<li><strong>#{data.total_rows}</strong> matches found.</li>")
              for row in data.rows
                if row.fields.slug
                  $item = $("<li><h3><a href=\"/#{row.fields.type}/#{row.fields.slug}\"><i class=\"icon icon-#{row.fields.type}\"></i>#{row.fields.title}</a></h3></li>")
                else
                  $item = $("<li><h3><a href=\"/\"><i class=\"icon icon-essay\"></i>Home</a></h3></li>")
                $searchResultsList.append($item)
            else
              $searchResultsList.html("<li>Server didn\'t respond with any data.</li>")

  $mainNavSearchInput.on 'keydown', performSearch
  $searchResultsInput.on 'keydown', performSearch

  # Setup the TOC menu
  if $tocNav and $articleView
    $articleView.find('h3').each ->
      heading = $(@)
      text = heading.text()
      headingId = 'TOC-' + text.replace(/[\ \_]/g, '-').replace(/[\'\"\.\?\#\:\,\;\@\=]/g, '')
      heading.attr('id', headingId)
      $tocNavList.append "<li><a href=\"##{headingId}\">#{text}</a></li>"

    # Decide if we should show the TOC
    if $tocNavList.children().length > 2
      $tocNav.show()
      $collectionNav.addClass('third')

    $tocNavIcon.on 'click', (e) ->
      e.stopPropagation()
      hidePopups($tocNavList)
      $tocNavList.toggle()
      $tocNavIcon.toggleClass('open')
      _gaq?.push(['_trackEvent', 'Site Navigation', 'Click', 'Document Nav Icon'])

  # Setup the Collection menu
  if $collectionNav
    collectionId = $collectionNav.attr('data-id')
    collectionSlug = $collectionNav.attr('data-slug')
    if collectionSlug
      # Grab the docs for the collection from DB
      $collectionNav.show()
      $.ajax
        type: 'GET'
        url: "/json/collection/#{collectionSlug}"
        contentType: 'json'
        success: (data) ->
          if data
            data = JSON.parse(data)
            collectionObject = null
            collectionSponsor = null
            
            for row in data.rows
              doc = row.doc
              collectionDocs.push(doc) if doc.type in settings.app.content_types
              collectionObject ?= doc if doc.type is 'collection'
              collectionSponsor ?= doc if doc.type is 'sponsor'

            # Loop through docs within collection
            for doc in collectionDocs
              url = "/#{doc.type}/#{doc.slug}"
              selectedClass = if window.location.pathname is url then 'active' else ''
              $collectionNavList.append "<li><a href=\"#{url}\" class=\"#{selectedClass}\" data-id=\"#{doc._id}\">#{doc.title}</a></li>"
            setupCollectionDocsNav(collectionDocs, $collectionNavList)

            # Setup collcetion sponsor inheritance if needed
            $loadSponsorSection = $('div[data-action="load-sponsor"]')
            if collectionSponsor and $loadSponsorSection
              collectionSponsor.text_format = collectionSponsor.format is 'text'
              collectionSponsor.image_format = collectionSponsor.format is 'image'
              collectionSponsor.video_format = collectionSponsor.format is 'video'
              collectionSponsor.embed_format = collectionSponsor.format is 'embed'
              collectionSponsor.for_type = collectionObject?.type
              collectionSponsor.for_type_tc = collectionObject?.type_tc
              $html = $(handlebars.templates['partials/sponsor.html']({sponsor: collectionSponsor}, {}))
              $html.insertAfter($loadSponsorSection)
              if collectionSponsor.include_default_ad_unit
                $loadSponsorSection.prependTo($html).removeClass('hide')
              else
                $loadSponsorSection.remove()
    else
      # Remove the doc nav prev and next arrows
      $('.doc-nav').remove()

    $collectionNavIcon.on 'click', (e) ->
      e.stopPropagation()
      hidePopups($collectionNavList)
      $collectionNavList.toggle()
      $collectionNavIcon.toggleClass('open')
      _gaq?.push(['_trackEvent', 'Site Navigation', 'Click', 'Collection Nav Icon'])


setupCollectionDocsNav = (docs, $collectionNavList) ->
  $docNav = $('.doc-nav')
  if $docNav
    $docNavPrev = $docNav.find('> .prev')
    $docNavNext = $docNav.find('> .next')
    $activeLink = $collectionNavList.find('.active')

    if $activeLink
      prev = -> $activeLink.parent().prev(':not(.heading)')?.find('a')[0]?.click()
      next = -> $activeLink.parent().next(':not(.heading)')?.find('a')[0]?.click()

      $docNavPrev.on 'click', ->
        if prev()
          $docNav.children().removeClass('disabled')
        else
          $docNavPrev.addClass('disabled')
        _gaq?.push(['_trackEvent', 'Site Navigation', 'Click', 'Doc Nav Prev'])
      
      $docNavNext.on 'click', ->
        if next()
          $docNav.children().removeClass('disabled')
        else
          $docNavNext.addClass('disabled')
        _gaq?.push(['_trackEvent', 'Site Navigation', 'Click', 'Doc Nav Next'])

      $(document).on 'keydown', (e) ->
        if e.which is 37
          $docNavPrev.click()
        else if e.which is 39
          $docNavNext.click()


setupSmoothScrolling = ->
  smoothScroll = (hash) ->
    $target = $(hash)
    $target = $target.length and $target or $('[name=' + hash.slice(1) +']')
    if $target.length
      adjustment = 15
      targetOffset = $target.offset().top - adjustment
      $('body').animate({scrollTop: targetOffset}, 400)
      return true
   
  # Add some smooth scrolling to anchor links
  $('body').on 'click', 'a[href*="#"]', (e) ->
    if location.pathname.replace(/^\//,'') is @pathname.replace(/^\//,'') and location.hostname is @hostname
      e.preventDefault()
      smoothScroll(@hash)
  
  # In case this is a distination to a specific page anchor, let's smooth scroll
  smoothScroll(location.hash) if location.hash.length
  

setupTimestampFormatting = ->
  # Convert UTC dates to local time
  $('.timestamp').each ->
    timestamp = $(@).text()
    $(@).html(moment(timestamp).local().format('MMM D, YYYY h:mm A'))


setupClickTracking = ->
  # Track some analytic events
  $('body').on 'click', '[data-track-click]', (e) ->
    label = $(@).attr('data-track-click');
    _gaq?.push(['_trackEvent', 'Tracked Items', 'Click', label])
    return true