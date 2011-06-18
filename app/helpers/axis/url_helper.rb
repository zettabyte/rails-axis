# encoding: utf-8
require 'axis/core_ext/hash'

module Axis
  module UrlHelper

    def path_for_self(anchor_or_options = nil, options = nil)
      return request.path unless anchor_or_options or options
      anchor = nil
      if options
        anchor = anchor_or_options
      else
        options = anchor_or_options
      end
      query_string = options.to_query
      result       = request.path
      result      << "?" + query_string unless query_string.blank?
      result      << "#" + anchor       unless anchor.blank?
      result
    end

    def qs_path_for_self(anchor_or_options = nil, options = nil)
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

    def url_for_self(anchor_or_options = nil, options = nil)
      request.protocol + request.host_with_port + path_for_self(anchor_or_options, options)
    end

    def qs_url_for_self(anchor_or_options = nil, options = nil)
      request.protocol + request.host_with_port + qs_path_for_self(anchor_or_options, options)
    end

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

    def qs_link_to_self(*args, &block)
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
        path         = only_path ? qs_path_for_self(anchor, options) : qs_url_for_self(anchor, options)
        link_to(name, path, html_options)
      end
    end

  end
end
