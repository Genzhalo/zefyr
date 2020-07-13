import 'package:notus/notus.dart';
import 'package:notus/src/link_rules.dart';
import 'package:quill_delta/quill_delta.dart';
import 'package:test/test.dart';


void main() {
  group('$LinkRules', () {
    test('link paste', () {
      final index  = 0;
      final url = 'https://google.com';
      expect(
        LinkRules().insert(Delta(), index, url),
        Delta()
          ..retain(index)
          ..insert(url, NotusAttribute.link.fromString(url).toJson())
      );     
    });

    test('add space after link', () {
      final url = 'https://google.com';
      final index = url.length;
      final doc = Delta()..insert(url)..insert('\n');
      expect(
        LinkRules().insert(doc, index, ' '),
        Delta()
          ..retain(index - url.length)
          ..retain(url.length, NotusAttribute.link.fromString(url).toJson())
          ..insert(' ')
      );   
    });

    test('insert space inside link', () {
      final index = 5;
      final url = 'https://google.com';
      final attr = NotusAttribute.link.fromString(url).toJson();
      final doc = Delta()
        ..insert(url, attr)
        ..insert('\n');
      expect(
        LinkRules().insert(doc, index, ' '),
        Delta()
          ..retain(index)
          ..insert(' ', attr)
      );
    });

    test('correct link', () {
      final firstPart = 'https';
      final secondtPart = '//google.com';
      final insertChar = ':';
      final doc = Delta()..insert(firstPart)..insert(secondtPart)..insert('\n');
      final url = (firstPart + insertChar + secondtPart).trim();
      final attr = NotusAttribute.link.fromString(url).toJson();
      expect(
        LinkRules().insert(doc, firstPart.length, insertChar),
        Delta()
          ..retain(firstPart.length, attr)
          ..insert(insertChar, attr)
          ..retain(secondtPart.trim().length, attr)
      );   
    });

    test('delete part of text', () {
      final firstText = 'https:';
      final secondText = '::::::::::';
      final thirdText = '//google.com';
      final doc = Delta()
        ..insert(firstText)
        ..insert(secondText)
        ..insert(thirdText)
        ..insert('\n');
      final attr = NotusAttribute.link.fromString('https://google.com').toJson();
      expect(
        LinkRules().delete(doc, firstText.length, secondText.length),
        Delta()
          ..retain(firstText.length, attr)
          ..delete(secondText.length)
          ..retain(thirdText.length, attr)
      );   
    });

    test('delete part of link', () {
      final firstPart = 'https://google.com';
      final secondPart = '/test';
      final thirdPart = '/123';
      final attr = NotusAttribute.link.fromString(firstPart + thirdPart).toJson();
      final doc = Delta()
        ..insert(firstPart, attr)
        ..insert(secondPart, attr)
        ..insert(thirdPart, attr)
        ..insert('\n');
      
      expect(
        LinkRules().delete(doc, firstPart.length, secondPart.length),
        Delta()
          ..retain(0)
          ..retain(firstPart.length, attr)
          ..delete(secondPart.length)
          ..retain(thirdPart.length, attr)
      );   
    });
  });
}