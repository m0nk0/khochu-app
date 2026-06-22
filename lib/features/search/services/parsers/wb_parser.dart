import 'base_parser.dart';
import 'js_scripts.dart';

class WbParser extends BaseParser {
  @override
  String get searchUrl => 'https://www.wildberries.ru/catalog/0/search.aspx?search=';
  
  @override
  String get jsInterceptor => JsScripts.wbJsonInterceptor;
  
  @override
  String get jsFallbackScript => JsScripts.wbSearchScript;
  
  @override
  String get marketplaceName => 'Wildberries';
  
  @override
  String get channelName => 'flutter_wb_handler';
}