$: << File.join(File.dirname(__FILE__), "/../lib")
require 'meta_inspector'
require 'fakeweb'
require "webmock/rspec"
require "pry"

FakeWeb.allow_net_connect = false
WebMock.disable!

def fixture_file(filename)
  return '' if filename == ''
  file_path = File.expand_path(File.dirname(__FILE__) + '/fixtures/' + filename)
  File.read(file_path)
end

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.treat_symbols_as_metadata_keys_with_true_values = true #rspec 3 default
end

#######################
# Faked web responses #
#######################

# We're reorganizing fixtures, trying to combine them on as few as possible response files
# For each change in the fixtures, a comment should be included explaining why it's needed
# This is the base page to be used in the examples
FakeWeb.register_uri(:get, "http://example.com/", :response => fixture_file("example.response"))

# Used to test response status codes
FakeWeb.register_uri(:get, "http://example.com/404", :response => fixture_file("404.response"))

# These are older fixtures
FakeWeb.register_uri(:get, "http://pagerankalert.com", :response => fixture_file("pagerankalert.com.response"))
FakeWeb.register_uri(:get, "http://pagerankalert-shortcut.com", :response => fixture_file("pagerankalert-shortcut.com.response"))
FakeWeb.register_uri(:get, "http://pagerankalert-shortcut-and-icon.com", :response => fixture_file("pagerankalert-shortcut-and-icon.com.response"))
FakeWeb.register_uri(:get, "http://pagerankalert-touch-icon.com", :response => fixture_file("pagerankalert-touch-icon.com.response"))
FakeWeb.register_uri(:get, "pagerankalert.com", :response => fixture_file("pagerankalert.com.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com", :response => fixture_file("alazan.com.response"))
FakeWeb.register_uri(:get, "http://alazan.com/websolution.asp", :response => fixture_file("alazan_websolution.response"))
FakeWeb.register_uri(:get, "http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/", :response => fixture_file("theonion.com.response"))
FakeWeb.register_uri(:get, "http://theonion-no-description.com", :response => fixture_file("theonion-no-description.com.response"))
FakeWeb.register_uri(:get, "http://www.iteh.at", :response => fixture_file("iteh.at.response"))
FakeWeb.register_uri(:get, "http://www.tea-tron.com/jbravo/blog/", :response => fixture_file("tea-tron.com.response"))
FakeWeb.register_uri(:get, "http://www.guardian.co.uk/media/pda/2011/sep/15/techcrunch-arrington-startups", :response => fixture_file("guardian.co.uk.response"))
FakeWeb.register_uri(:get, "http://protocol-relative.com", :response => fixture_file("protocol_relative.response"))
FakeWeb.register_uri(:get, "https://protocol-relative.com", :response => fixture_file("protocol_relative.response"))
FakeWeb.register_uri(:get, "http://example.com/nonhttp", :response => fixture_file("nonhttp.response"))
FakeWeb.register_uri(:get, "http://example.com/invalid_href", :response => fixture_file("invalid_href.response"))
FakeWeb.register_uri(:get, "http://example.com/malformed_href", :response => fixture_file("malformed_href.response"))
FakeWeb.register_uri(:get, "http://www.youtube.com/watch?v=iaGSSrp49uc", :response => fixture_file("youtube.response"))
FakeWeb.register_uri(:get, "http://markupvalidator.com/faqs", :response => fixture_file("markupvalidator_faqs.response"))
FakeWeb.register_uri(:get, "https://twitter.com/markupvalidator", :response => fixture_file("twitter_markupvalidator.response"))
FakeWeb.register_uri(:get, "http://example.com/empty", :response => fixture_file("empty_page.response"))
FakeWeb.register_uri(:get, "http://international.com", :response => fixture_file("international.response"))
FakeWeb.register_uri(:get, "http://charset000.com", :response => fixture_file("charset_000.response"))
FakeWeb.register_uri(:get, "http://charset001.com", :response => fixture_file("charset_001.response"))
FakeWeb.register_uri(:get, "http://charset002.com", :response => fixture_file("charset_002.response"))
FakeWeb.register_uri(:get, "http://www.inkthemes.com/", :response => fixture_file("wordpress_site.response"))
FakeWeb.register_uri(:get, "http://pagerankalert.com/image.png", :body => "Image", :content_type => "image/png")
FakeWeb.register_uri(:get, "http://pagerankalert.com/file.tar.gz", :body => "Image", :content_type => "application/x-gzip")
FakeWeb.register_uri(:get, "http://example.com/meta-tags", :response => fixture_file("meta_tags.response"))

# These examples are used to test relative links
FakeWeb.register_uri(:get, "http://relative.com/", :response => fixture_file("relative_links.response"))
FakeWeb.register_uri(:get, "http://relative.com/company", :response => fixture_file("relative_links.response"))
FakeWeb.register_uri(:get, "http://relative.com/company/", :response => fixture_file("relative_links.response"))

FakeWeb.register_uri(:get, "http://relativewithbase.com/",                :response => fixture_file("relative_links_with_base.response"))
FakeWeb.register_uri(:get, "http://relativewithbase.com/company/page2",   :response => fixture_file("relative_links_with_base.response"))
FakeWeb.register_uri(:get, "http://relativewithbase.com/company/page2/",  :response => fixture_file("relative_links_with_base.response"))

# These examples are used to test the redirections from HTTP to HTTPS and vice versa
# http://facebook.com => https://facebook.com
FakeWeb.register_uri(:get, "http://facebook.com/",          :response => fixture_file("facebook.com.response"))
FakeWeb.register_uri(:get, "https://www.facebook.com/",     :response => fixture_file("https.facebook.com.response"))

# https://unsafe-facebook.com => http://unsafe-facebook.com
FakeWeb.register_uri(:get, "https://unsafe-facebook.com/",  :response => fixture_file("unsafe_https.facebook.com.response"))
FakeWeb.register_uri(:get, "http://unsafe-facebook.com/",   :response => fixture_file("unsafe_facebook.com.response"))

# These examples are used to test normalize URLs
FakeWeb.register_uri(:get, "http://example.com/%EF%BD%9E", :response => fixture_file("example.response"))
FakeWeb.register_uri(:get, "http://example.com/~", :response => fixture_file("example.response"))

# These images are used to test best image selection
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/bannercamara.gif", :response => fixture_file("alazan.com_imagenes_bannercamara.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/boton_entrar.gif", :response => fixture_file("alazan.com_imagenes_boton_entrar.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/cabecera_extranet.gif", :response => fixture_file("alazan.com_imagenes_cabecera_extranet.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/correo_info.gif", :response => fixture_file("alazan.com_imagenes_correo_info.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/desplegable_alojamiento.gif", :response => fixture_file("alazan.com_imagenes_desplegable_alojamiento.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/desplegable_cdroms.gif", :response => fixture_file("alazan.com_imagenes_desplegable_cdroms.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/desplegable_contratar.gif", :response => fixture_file("alazan.com_imagenes_desplegable_contratar.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/desplegable_demo.gif", :response => fixture_file("alazan.com_imagenes_desplegable_demo.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/desplegable_intranets.gif", :response => fixture_file("alazan.com_imagenes_desplegable_intranets.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/desplegable_oferta.gif", :response => fixture_file("alazan.com_imagenes_desplegable_oferta.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/desplegable_preguntas.gif", :response => fixture_file("alazan.com_imagenes_desplegable_preguntas.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/desplegable_premium.gif", :response => fixture_file("alazan.com_imagenes_desplegable_premium.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/desplegable_profesional.gif", :response => fixture_file("alazan.com_imagenes_desplegable_profesional.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/desplegable_tabla.gif", :response => fixture_file("alazan.com_imagenes_desplegable_tabla.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/desplegable_trabaja.gif", :response => fixture_file("alazan.com_imagenes_desplegable_trabaja.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/desplegable_ventajas.gif", :response => fixture_file("alazan.com_imagenes_desplegable_ventajas.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/desplegable_webcams.gif", :response => fixture_file("alazan.com_imagenes_desplegable_webcams.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/index_principal1.jpg", :response => fixture_file("alazan.com_imagenes_index_principal1.jpg.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/index_principal2.gif", :response => fixture_file("alazan.com_imagenes_index_principal2.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/logo.jpg", :response => fixture_file("alazan.com_imagenes_logo.jpg.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/mas.gif", :response => fixture_file("alazan.com_imagenes_mas.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/menu_dch_soporte.gif", :response => fixture_file("alazan.com_imagenes_menu_dch_soporte.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/menu_distribuidores.gif", :response => fixture_file("alazan.com_imagenes_menu_distribuidores.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/menu_que.gif", :response => fixture_file("alazan.com_imagenes_menu_que.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/menu_websolution.gif", :response => fixture_file("alazan.com_imagenes_menu_websolution.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/menusep.gif", :response => fixture_file("alazan.com_imagenes_menusep.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/nh-alojamiento.gif", :response => fixture_file("alazan.com_imagenes_nh_alojamiento.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/nh-cdroms.gif", :response => fixture_file("alazan.com_imagenes_nh_cdroms.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/nh-desarrollo-web.gif", :response => fixture_file("alazan.com_imagenes_nh_desarrollo_web.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/nh-dominios.gif", :response => fixture_file("alazan.com_imagenes_nh_dominios.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/nh-gestor-contenidos.gif", :response => fixture_file("alazan.com_imagenes_nh_gestor_contenidos.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/nh-otros-servicios.gif", :response => fixture_file("alazan.com_imagenes_nh_otros_servicios.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/nh-webcams.gif", :response => fixture_file("alazan.com_imagenes_nh_webcams.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/nh_que-hacemos.gif", :response => fixture_file("alazan.com_imagenes_nh_que_hacemos.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/sp.gif", :response => fixture_file("alazan.com_imagenes_sp.gif.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com/imagenes/webcam_guarderia_02.jpg", :response => fixture_file("alazan.com_imagenes_webcam_guarderia_02.jpg.response"))

