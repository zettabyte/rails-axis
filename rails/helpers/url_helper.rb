# encoding: utf-8
require 'axis/core_ext/hash'

module Axis
  module UrlHelper

    #
    # Returns the path part of the url used for the current request, including
    # the query-string, if present. You may provide a string as the first
    # parameter in which case the provided string will be appended to the
    # returned url as a "fragment identifier" (or "anchor"). You may also
    # provide a hash, where the keys are strings or symbols, as the last or only
    # parameter. If provided, the hash defines one or more query-string
    # parameter values you wish to set.
    #
    # If the original query-string value has the same name as a value passed in
    # your hash, the old value will be replaced with the value you provide. If
    # you provide nil for such a value, then the named query-string value will
    # be omitted. Thus, you can "delete", "update", or "create" query-string
    # values at will.
    #
    # Note that if you don't pass any parameters (no anchor or options) then
    # the path from the current request is simply returned.
    #
    # Use #url_for_self (below) if you want an equivalent method that returns
    # an entire url instead of just the path part.
    #
    # == Why?
    #
    # The #url_for method, when called with no parameters, also returns the path
    # part of the url used for the current resource. The key word here, however,
    # is "resource". It always returns the (most) "canonical" path for the
    # resource "loaded" by the router during the request. Most of the time this
    # is also the same path used to actually request the resource. However, if
    # you have a resource with *multiple* legitimate routes and you request the
    # resource using one that isn't the "canonical" one (i.e. the highest-up in
    # the config/routes.rb file) then #url_for will return a path that is
    # actually *different* than the one used by the current request.
    #
    # Another difference between #url_for and #path_for_self is that #url_for,
    # by default, doesn't include any of the query-string parameters passed as
    # part of the current request. You have to manually do something like the
    # following in order to achieve behavior similar to #path_for_self:
    #
    #     url_for(request.query_parameters) == path_for_self # most of the time
    #
    # The other difference between #url_for and #path_for_self is that #url_for,
    # if passed any options that match any of the special values defined by the
    # matching route (which always includes "controller" and "action" and often
    # "id") then these options are (correctly) consumed to generate a new path.
    # In such a case you may end up with a path that doesn't even refer to the
    # current resource at all. The #path_for_self method, however,  facilitates
    # the situation where I may want include one of the special-named options in
    # my query-string: "/users/1?action=next" (contrived pagination system that
    # uses the params["action"] to select page to display).
    #
    # == Examples
    #
    #     request.fullpath
    #       => "/users/1?page=2"
    #
    #     url_for
    #       => "/users/1"
    #
    #     path_for_self
    #       => "/users/1?page=2"
    #
    #     path_for_self(:details)
    #       => "/users/1?page=2#details"
    #
    #     path_for_self(:page => nil)
    #       => "/users/1
    #
    #     path_for_self("log", :page => 4, :order => :desc)
    #       => "/users/1?page=4&order=desc#log
    #
    #     path_for_self("log", :anchor => "janet", :controller => "bob")
    #       => "/users/1?anchor=janet&controller=bob#log
    #
    #     url_for(:anchor => "janet", :controller => "bob")
    #       => ActionController::RoutingError (no route matches {:controller=>"bob"})
    #
    #     url_for(:anchor => "janet", :controller => "blogs")
    #       => "/blogs#janet"
    #
    def path_for_self(anchor_or_options = nil, options = nil)
      return request.fullpath unless anchor_or_options or options
      anchor = nil
      if options
        anchor = anchor_or_options
      else
        options = anchor_or_options
      end
      query_string = request.query_parameters.deep_merge(options.deep_stringify_keys).reject { |k, v| v.nil? }.to_query
      result       = request.path
      result      << "?" + query_string unless query_string.blank?
      result      << "#" + anchor       unless anchor.blank?
      result
    end

    #
    # This is like #path_for_self (above) except that it returns a full url
    # (including scheme, host, and port) instead of just the path-part of the
    # url. Usage is otherwise the same.
    #
    def url_for_self(anchor_or_options = nil, options = nil)
      request.protocol + request.host_with_port + path_for_self(anchor_or_options, options)
    end

    #
    # This will create a link to the current document with the provided options
    # being added to the url as query-string parameters. You may either provide
    # the link text (the body) as the first parameter, or instead provide a
    # block that returns the content of the link. You may also provide a
    # standard html_options hash.
    #
    # In addition to adding any provided options as parameters to the query
    # string this will also add all query string parameters from the current
    # request back into the query string as well. To override an existing query
    # string parameter, simply provide an option of the same name (string or
    # symbol form) with the new value. If the new value is nil, the existing
    # parameter will be omitted. All non-string values will be converted using
    # #to_s.
    #
    # However, there are two special options:
    #
    #     :anchor    => specify an anchor name to be appended to the path.
    #     :only_path => if true, returns the path-part of the url only (this is
    #                   the default); otherwise (nil or false) the full url is
    #                   returned (including protocol, host, and port).
    #
    # For these options to be recognized (and not just have their values added
    # to the query-string) you must use the symbol form for the keys (not
    # strings). This allows you to have an "?anchor=away" or "?only_path=yes"
    # query-string by using "anchor" => "away" or "only_path" => "yes"
    # respectively.
    #
    # == Signatures
    #
    #     link_to_self(body, options = {}, html_options = {})
    #       # body is the "name" (contents) of the link
    #
    #     link_to_self(options = {}, html_options = {}) do
    #       # link contents defined here
    #     end
    #
    def link_to_self(*args, &block)
      if block_given?
        options      = args.first || {}
        html_options = args.second
        link_to_self(capture(&block), options, html_options)
      else
        name         = args[0]
        options      = args[1] ? args[1].dup : {}
        html_options = args[2]
        only_path    = true
        only_path    = options.delete(:only_path) if options.has_key?(:only_path)
        anchor       = options.delete(:anchor)
        path         = only_path ? path_for_self(anchor, options) : url_for_self(anchor, options)
        link_to(name, path, html_options)
      end
    end

  end
end
