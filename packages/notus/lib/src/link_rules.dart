import 'package:notus/notus.dart';
import 'package:quill_delta/quill_delta.dart';

const webUrlPattern =
    // protocol identifier (optional)
    // short syntax // still required
    '(?:(?:(?:https?|ftp):)?\\/\\/)' +
    // user:pass BasicAuth (optional)
    '(?:\\S+(?::\\S*)?@)?' +
    '(?:' +
    // IP address exclusion
    // private & local networks
    '(?!(?:10|127)(?:\\.\\d{1,3}){3})' +
    '(?!(?:169\\.254|192\\.168)(?:\\.\\d{1,3}){2})' +
    '(?!172\\.(?:1[6-9]|2\\d|3[0-1])(?:\\.\\d{1,3}){2})' +
    // IP address dotted notation octets
    // excludes loopback network 0.0.0.0
    // excludes reserved space >= 224.0.0.0
    // excludes network & broadcast addresses
    // (first & last IP address of each class)
    '(?:[1-9]\\d?|1\\d\\d|2[01]\\d|22[0-3])' +
    '(?:\\.(?:1?\\d{1,2}|2[0-4]\\d|25[0-5])){2}' +
    '(?:\\.(?:[1-9]\\d?|1\\d\\d|2[0-4]\\d|25[0-4]))' +
    '|' +
    // host & domain names, may end with dot
    // can be replaced by a shortest alternative
    // (?![-_])(?:[-\\w\\u00a1-\\uffff]{0,63}[^-_]\\.)+
    '(?:' +
    '(?:' +
    '[a-z0-9\\u00a1-\\uffff]' +
    '[a-z0-9\\u00a1-\\uffff_-]{0,62}' +
    ')?' +
    '[a-z0-9\\u00a1-\\uffff]\\.' +
    ')+' +
    // TLD identifier name, may end with dot
    '(?:[a-z\\u00a1-\\uffff]{2,}\\.?)' +
    ')' +
    // port number (optional)
    '(?::\\d{2,5})?' +
    // resource path (optional)
    '(?:[/?#]\\S*)?';


class LinkRules {


  Delta insert(Delta document, int index, String text) {
    
    if (_isLink(text, asPart: false)){
      return Delta()
        ..retain(index)
        ..insert(text, _getAttr(text.trim()));
    }

    final iter = DeltaIterator(document);
    final prev = iter.skip(index);
    if (prev == null) return null;

    final next = iter.next();
    var candidate = prev.data.split('\n').last.split(' ').last;

    var nextFirstWord = '';
    if (next != null) nextFirstWord = next.data.split('\n').first.split(' ').first;
    final url = candidate + text + nextFirstWord;

    if (_isLink(url, asPart: false)) {
      final attr = (prev.attributes ?? {})..addAll(_getAttr(url));
      return Delta()
        ..retain(index - candidate.length)
        ..retain(candidate.length, attr)
        ..insert(text, attr)
        ..retain(nextFirstWord.length, attr);
    }

    if (_hasLink(prev) && _hasLink(next) ) {
      return Delta()
        ..retain(index)
        ..insert(text, prev.attributes);
    }

    if (text == ' ') {
      final attr = (prev.attributes ?? {})..remove(NotusAttribute.link.key);
      final textAttr = attr.isEmpty ? null : attr;
      if (_isLink(candidate, asPart: false)) {
        return Delta()
          ..retain(index - candidate.length)
          ..retain(candidate.length, attr..addAll(_getAttr(candidate)))
          ..insert(text, textAttr);
      } else {
        return Delta()
          ..retain(index)
          ..insert(text, textAttr);
      }
    }

    if (_hasLink(prev) ){
      return Delta()
        ..retain(index)
        ..insert(text, prev.attributes);
    } 

    return null;
  }

  Delta delete(Delta document, int index, int length) {
    var iter = DeltaIterator(document);
    final previous = iter.skip(index);
    if (previous == null) return null;
    final next = iter.next();
    // edit link
    // 1. next is avavilbe
    // 2. next is link
    // 3. next has the same attributes that prev
    // 4. delete count less that next link 
    if (next != null && length < next.data.length){
      final nextData = next.data.substring(length).trim();
      final url = previous.data + nextData;
      if (_isLink(url, asPart: false)) {
        final attributes = (next.attributes ?? {})..addAll(_getAttr(url));
        return Delta()
          ..retain(index - previous.data.length)
          ..retain(previous.data.length, attributes)
          ..delete(length)
          ..retain(nextData.length, attributes);
      }
    }
    return null;
  }

    
  bool _hasLink(Operation operation) =>
    operation != null && operation.attributes != null && operation.attributes.containsKey(NotusAttribute.link.key);

  bool _isLink(String text, { bool asPart = true }) {
    var source = '^$webUrlPattern';
    if (!asPart) source += '\$';
    return RegExp(source, caseSensitive: false).hasMatch(text);
  }

  Map<String, dynamic> _getAttr(String text) {
    if (text.startsWith('//')) text = 'https:' + text;
    return NotusAttribute.link.fromString(text.toLowerCase()).toJson();
  } 
}