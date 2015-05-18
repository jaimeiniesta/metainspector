require 'spec_helper'

describe MetaInspector do

  describe "head_links" do
    let(:page) { MetaInspector.new('http://example.com/head_links') }

    it "#head_links" do
      expect(page.head_links).to eq([
                                        {rel: 'canonical', href: 'http://example.com/canonical-from-head'},
                                        {rel: 'stylesheet', href: '/stylesheets/screen.css'},
                                        {rel: 'shortcut icon', href: '/favicon.ico', type: 'image/x-icon'},
                                        {rel: 'shorturl', href: 'http://gu.com/p/32v5a'},
                                        {rel: 'stylesheet', type: 'text/css', href: 'http://foo/print.css', media: 'print', class: 'contrast'}
                                    ])
    end

    it "#stylesheets" do
      expect(page.stylesheets).to eq([
                                         {rel: 'stylesheet', href: '/stylesheets/screen.css'},
                                         {rel: 'stylesheet', type: 'text/css', href: 'http://foo/print.css', media: 'print', class: 'contrast'}
                                     ])
    end

    it "#canonical" do
      expect(page.canonicals).to eq([
                                        {rel: 'canonical', href: 'http://example.com/canonical-from-head'}
                                    ])
    end

  end

end
