import 'base_parser.dart';
import 'js_scripts.dart';

class OzonParser extends BaseParser {
  @override
  String get searchUrl => 'https://www.ozon.ru/search/?text=';
  
  @override
  String get jsInterceptor => JsScripts.ozonJsonInterceptor;
  
  @override
  String get jsFallbackScript => JsScripts.ozonSearchScript;
  
  @override
  String get marketplaceName => 'Ozon';
  
  @override
  String get channelName => 'flutter_ozon_handler';
}