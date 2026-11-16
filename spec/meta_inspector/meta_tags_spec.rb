require 'spec_helper'

describe MetaInspector do
  describe "meta tags" do
    let(:page) { MetaInspector.new('http://example.com/meta-tags') }

    it "#meta_tags" do
      expect(page.meta_tags).to eq({
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
                                })
    end

    it "#meta_tag" do
      expect(page.meta_tag).to eq({
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
                                })
    end

    it "#meta" do
      expect(page.meta).to eq({
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
                          })
    end
  end

  describe 'Charset detection' do
    it "should get the charset from <meta charset />" do
      page = MetaInspector.new('http://charset001.com')

      expect(page.charset).to eq("utf-8")
    end

    it "should get the charset from meta content type" do
      page = MetaInspector.new('http://charset002.com')

      expect(page.charset).to eq("windows-1252")
    end

    it "should get nil if no declared charset is found" do
      page = MetaInspector.new('http://charset000.com')

      expect(page.charset).to eq(nil)
    end

    ['Content-Type', 'content-type', 'Content-type', 'CONTENT-TYPE'].each do |http_equiv|
      it "gets the charset when http-equiv is #{http_equiv}" do
        html = %(<meta http-equiv="#{http_equiv}" content="text/html; charset=utf-8">)
        page = MetaInspector.new('http://example.com', document: html)

        expect(page.charset).to eq('utf-8')
      end
    end

    {
      'text/html; foo=bar; charset=utf-8' => 'utf-8',
      'text/html; charset=utf-8; foo=bar' => 'utf-8',
      'text/html; charset = utf-8 ' => 'utf-8',
      "text/html;\tCHARSET\t=\tUTF-8" => 'UTF-8',
      'text/html; charset="utf-8"' => 'utf-8',
      "text/html; charset='utf-8'" => 'utf-8',
      'text/html; foo=bar' => nil,
      'text/html; othercharset=utf-8' => nil,
      'text/html; charset' => nil,
      'text/html; charset=' => nil,
      'text/html' => nil
    }.each do |content, charset|
      it "gets #{charset.inspect} from the content #{content.inspect}" do
        html = %(<meta http-equiv="Content-Type" content="#{content.gsub('"', '&quot;')}">)
        page = MetaInspector.new('http://example.com', document: html)

        expect(page.charset).to eq(charset)
      end
    end

    it 'returns nil when the content-type meta tag has no content attribute' do
      page = MetaInspector.new('http://example.com', document: '<meta http-equiv="content-type">')

      expect(page.charset).to be_nil
    end

    it 'prefers a meta charset attribute over a content-type declaration' do
      html = '<meta http-equiv="content-type" content="text/html; charset=windows-1252">' \
             '<meta charset="utf-8">'
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.charset).to eq('utf-8')
    end

    it 'uses the first content-type declaration and ignores other http-equiv values' do
      html = '<meta http-equiv="refresh" content="0; charset=windows-1252">' \
             '<meta http-equiv="content-type" content="text/html; charset=utf-8">' \
             '<meta http-equiv="Content-Type" content="text/html; charset=windows-1252">'
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.charset).to eq('utf-8')
    end
  end
end
