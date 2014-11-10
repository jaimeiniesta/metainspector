require 'spec_helper'

describe MetaInspector do

  describe "meta tags" do
    let(:page) { MetaInspector.new('http://example.com/meta-tags') }

    it "#meta_tags" do
      page.meta_tags.should == {
                                  'name' => {
                                              'keywords'       => ['one, two, three'],
                                              'description'    => ['the description'],
                                              'author'         => ['Joe Sample'],
                                              'robots'         => ['index,follow'],
                                              'revisit'        => ['15 days'],
                                              'dc.date.issued' => ['2011-09-15']
                                             },

                                  'http-equiv' => {
                                                    'content-type'        => ['text/html; charset=UTF-8'],
                                                    'content-style-type'  => ['text/css']
                                                  },

                                  'property' => {
                                                  'og:title'        => ['An OG title'],
                                                  'og:type'         => ['website'],
                                                  'og:url'          => ['http://example.com/meta-tags'],
                                                  'og:image'        => ['http://example.com/rock.jpg',
                                                                        'http://example.com/rock2.jpg',
                                                                        'http://example.com/rock3.jpg'],
                                                  'og:image:width'  => ['300'],
                                                  'og:image:height' => ['300', '1000']
                                                },

                                  'charset' => ['UTF-8']
                                }
    end

    it "#meta_tag" do
      page.meta_tag.should == {
                                  'name' => {
                                              'keywords'       => 'one, two, three',
                                              'description'    => 'the description',
                                              'author'         => 'Joe Sample',
                                              'robots'         => 'index,follow',
                                              'revisit'        => '15 days',
                                              'dc.date.issued' => '2011-09-15'
                                             },

                                  'http-equiv' => {
                                                    'content-type'        => 'text/html; charset=UTF-8',
                                                    'content-style-type'  => 'text/css'
                                                  },

                                  'property' => {
                                                  'og:title'        => 'An OG title',
                                                  'og:type'         => 'website',
                                                  'og:url'          => 'http://example.com/meta-tags',
                                                  'og:image'        => 'http://example.com/rock.jpg',
                                                  'og:image:width'  => '300',
                                                  'og:image:height' => '300'
                                                },

                                  'charset' => 'UTF-8'
                                }
    end

    it "#meta" do
      page.meta.should == {
                            'keywords'            => 'one, two, three',
                            'description'         => 'the description',
                            'author'              => 'Joe Sample',
                            'robots'              => 'index,follow',
                            'revisit'             => '15 days',
                            'dc.date.issued'      => '2011-09-15',
                            'content-type'        => 'text/html; charset=UTF-8',
                            'content-style-type'  => 'text/css',
                            'og:title'            => 'An OG title',
                            'og:type'             => 'website',
                            'og:url'              => 'http://example.com/meta-tags',
                            'og:image'            => 'http://example.com/rock.jpg',
                            'og:image:width'      => '300',
                            'og:image:height'     => '300',
                            'charset'             => 'UTF-8'
                          }
    end
  end

  describe 'Charset detection' do
    it "should get the charset from <meta charset />" do
      page = MetaInspector.new('http://charset001.com')

      page.charset.should == "utf-8"
    end

    it "should get the charset from meta content type" do
      page = MetaInspector.new('http://charset002.com')

      page.charset.should == "windows-1252"
    end

    it "should get nil if no declared charset is found" do
      page = MetaInspector.new('http://charset000.com')

      page.charset.should == nil
    end
  end
end
