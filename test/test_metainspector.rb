require 'test/unit'
require '../lib/metainspector.rb'

class TestMetaInspector < Test::Unit::TestCase
  # TODO: mock tests
  # TODO: validate URL format, only http and https allowed
  # TODO: check timeouts
  
  # Test scraping an URL, marking it as scraped and setting meta data values
  def test_scrape
    m = MetaInspector.new('http://pagerankalert.com')
    assert_equal m.title, 'PageRankAlert.com :: Track your pagerank changes'
    assert_equal m.description, 'Track your PageRank(TM) changes and receive alert by email'
    assert_equal m.keywords, 'pagerank, seo, optimization, google'
    assert_equal m.links.size, 7
    assert_equal m.links[0], "/"
    assert_equal m.parsed_document.class, Nokogiri::HTML::Document
    assert_equal m.document.class, String
    #assert_equal 'utf-8', m.charset
  end
  
  def test_charsets
    m = MetaInspector.new('http://www.alazan.com')
    assert_equal "iso-8859-2", m.charset
    
    m = MetaInspector.new('http://www.railes.net')
    assert_equal "utf-8", m.charset    
  end 
  
  def test_parse_iso_8859_1
    #m = MetaInspector.new("http://www.alazan.com")
    #assert_equal m.charset, 'iso-8859-2'
    #assert_equal m.title, "Diseño páginas web al mejor precio - Desarrollo Multimedia - Alazán Internet"
    #assert_equal m.description, "Alazán Internet - Páginas web profesionales al mejor precio. Presencia en Internet desde 20 euros/mes. GRATIS alta en buscadores."
    #assert_equal m.keywords, "paginas web, diseño web, sitio web, internet, programacion, aplicaciones, creacion,desarrollo, web, bases de datos,boletin de noticias,buscadores,cd card,cd rom,comercio electronico,descuento,dinero,diseño,dominio,extranet,gestion dominios,gestor de contenidos,gratis,hosting,intranet,lista correo,llave en mano,marketing,mejor precio,mejora página,multimedia,negocio,página,pagina web,pequeña y mediana empresa,pequeño negocio,plantillas diseño,portal,precio,prediseñadas,presencia,presentacion flash,profesional,programacion,promocion buscadores,publicidad,red,sitio,webcam,websolution,zona privada"
  end   
end
