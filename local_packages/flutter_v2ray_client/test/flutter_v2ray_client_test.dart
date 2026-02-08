import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('V2ray URL Parsing Tests', () {
    test('should parse vmess URL correctly', () {
      const vmessUrl =
          'vmess://eyJ2IjoiMiIsInBzIjoiVGVzdCBTZXJ2ZXIiLCJhZGQiOiIxMC4wLjAuMSIsInBvcnQiOiI0NDMiLCJpZCI6IjEyMzQ1Njc4LWFiY2QtMTIzNC1hYmNkLTEyMzQ1Njc4YWJjZCIsImFpZCI6IjAiLCJuZXQiOiJ0Y3AiLCJ0eXBlIjoibm9uZSIsImhvc3QiOiIiLCJwYXRoIjoiIiwidGxzIjoiIn0=';

      expect(() => V2ray.parseFromURL(vmessUrl), returnsNormally);
      final parsed = V2ray.parseFromURL(vmessUrl);
      expect(parsed, isA<V2RayURL>());
      expect(parsed.remark, equals('Test Server'));
    });

    test('should parse vless URL correctly', () {
      const vlessUrl =
          'vless://12345678-abcd-1234-abcd-12345678abcd@10.0.0.1:443?type=tcp&security=tls&sni=example.com#Test VLESS';

      expect(() => V2ray.parseFromURL(vlessUrl), returnsNormally);
      final parsed = V2ray.parseFromURL(vlessUrl);
      expect(parsed, isA<V2RayURL>());
      expect(parsed.remark, equals('Test VLESS'));
    });

    test('should parse vless URL with xhttp transport correctly', () {
      const vlessXhttpUrl =
          'vless://ad44a6ac-311c-4c9e-bd80-c661925a9f6d@185.254.220.229:1002?mode=auto&path=%2FApi%2FAS&security=reality&encryption=none&extra=%7B%22scMaxEachPostBytes%22%3A%20750000%2C%20%22scMaxConcurrentPosts%22%3A%2040%2C%20%22scMinPostsIntervalMs%22%3A%2020%2C%20%22xPaddingBytes%22%3A%20%22500-1500%22%2C%20%22noGRPCHeader%22%3A%20false%7D&pbk=O1Qz_PG-FGREdqahdH6ZjWADCK8n97IwszExalkxunk&fp=firefox&type=xhttp&sni=cdn.jsdelivr.net&sid=77a2017d25f1be8d#%F0%9F%87%B5%F0%9F%87%B1%20%7C%20Direct%20Reality';

      expect(() => V2ray.parseFromURL(vlessXhttpUrl), returnsNormally);
      final parsed = V2ray.parseFromURL(vlessXhttpUrl);
      expect(parsed, isA<V2RayURL>());
      expect(parsed.remark, equals('🇵🇱 | Direct Reality'));
      expect(parsed.address, equals('185.254.220.229'));
      expect(parsed.port, equals(1002));
    });

    test('should parse vless URL with httpupgrade transport correctly', () {
      const vlessHttpupgradeUrl =
          'vless://e390c1ee-dffd-4a5d-82f5-a4a9a8ee4e80@69.84.182.90:8880?security=&encryption=none&host=suddhdussn.hide-abr.com.tr.&type=httpupgrade#%F0%9F%87%A9%F0%9F%87%AA%20%7C%20CDN';

      expect(() => V2ray.parseFromURL(vlessHttpupgradeUrl), returnsNormally);
      final parsed = V2ray.parseFromURL(vlessHttpupgradeUrl);
      expect(parsed, isA<V2RayURL>());
      expect(parsed.remark, equals('🇩🇪 | CDN'));
      expect(parsed.address, equals('69.84.182.90'));
      expect(parsed.port, equals(8880));
    });

    test('should throw ArgumentError for invalid URL', () {
      const invalidUrl = 'invalid://url';

      expect(() => V2ray.parseFromURL(invalidUrl), throwsArgumentError);
    });

    test('should throw ArgumentError for unsupported protocol', () {
      const unsupportedUrl = 'unsupported://example.com';

      expect(() => V2ray.parseFromURL(unsupportedUrl), throwsArgumentError);
    });
  });

  group('XHTTP URL Specific Tests', () {
    test('should correctly parse VLESS URL with xhttp transport', () {
      const vlessXhttpUrl =
          'vless://ad44a6ac-311c-4c9e-bd80-c661925a9f6d@185.254.220.229:1002?mode=auto&path=%2FApi%2FAS&security=reality&encryption=none&extra=%7B%22scMaxEachPostBytes%22%3A%20750000%2C%20%22scMaxConcurrentPosts%22%3A%2040%2C%20%22scMinPostsIntervalMs%22%3A%2020%2C%20%22xPaddingBytes%22%3A%20%22500-1500%22%2C%20%22noGRPCHeader%22%3A%20false%7D&pbk=O1Qz_PG-FGREdqahdH6ZjWADCK8n97IwszExalkxunk&fp=firefox&type=xhttp&sni=cdn.jsdelivr.net&sid=77a2017d25f1be8d#%F0%9F%87%B5%F0%9F%87%B1%20%7C%20Direct%20Reality';

      final vless = V2ray.parseFromURL(vlessXhttpUrl);
      
      expect(vless.address, equals('185.254.220.229'));
      expect(vless.port, equals(1002));
      expect(vless.remark, equals('🇵🇱 | Direct Reality'));
    });

    test('should generate correct xhttp stream settings', () {
      const vlessXhttpUrl =
          'vless://ad44a6ac-311c-4c9e-bd80-c661925a9f6d@185.254.220.229:1002?mode=auto&path=%2FApi%2FAS&security=reality&encryption=none&extra=%7B%22scMaxEachPostBytes%22%3A%20750000%2C%20%22scMaxConcurrentPosts%22%3A%2040%2C%20%22scMinPostsIntervalMs%22%3A%2020%2C%20%22xPaddingBytes%22%3A%20%22500-1500%22%2C%20%22noGRPCHeader%22%3A%20false%7D&pbk=O1Qz_PG-FGREdqahdH6ZjWADCK8n97IwszExalkxunk&fp=firefox&type=xhttp&sni=cdn.jsdelivr.net&sid=77a2017d25f1be8d#%F0%9F%87%B5%F0%9F%87%B1%20%7C%20Direct%20Reality';

      final vless = V2ray.parseFromURL(vlessXhttpUrl);
      final streamSettings = vless.streamSetting;
      
      expect(streamSettings['network'], equals('xhttp'));
      expect(streamSettings['security'], equals('reality'));
      
      final xhttpSettings = streamSettings['xhttpSettings'] as Map;
      expect(xhttpSettings['mode'], equals('auto'));
      expect(xhttpSettings['path'], equals('/Api/AS'));
      expect(xhttpSettings['host'], equals(''));
      
      final extra = xhttpSettings['extra'] as Map;
      expect(extra['scMaxEachPostBytes'], equals(750000));
      expect(extra['scMaxConcurrentPosts'], equals(40));
      expect(extra['scMinPostsIntervalMs'], equals(20));
      expect(extra['xPaddingBytes'], equals('500-1500'));
      expect(extra['noGRPCHeader'], equals(false));
    });

    test('should generate complete xhttp configuration', () {
      const vlessXhttpUrl =
          'vless://ad44a6ac-311c-4c9e-bd80-c661925a9f6d@185.254.220.229:1002?mode=auto&path=%2FApi%2FAS&security=reality&encryption=none&extra=%7B%22scMaxEachPostBytes%22%3A%20750000%2C%20%22scMaxConcurrentPosts%22%3A%2040%2C%20%22scMinPostsIntervalMs%22%3A%2020%2C%20%22xPaddingBytes%22%3A%20%22500-1500%22%2C%20%22noGRPCHeader%22%3A%20false%7D&pbk=O1Qz_PG-FGREdqahdH6ZjWADCK8n97IwszExalkxunk&fp=firefox&type=xhttp&sni=cdn.jsdelivr.net&sid=77a2017d25f1be8d#%F0%9F%87%B5%F0%9F%87%B1%20%7C%20Direct%20Reality';

      final vless = V2ray.parseFromURL(vlessXhttpUrl);
      final config = vless.getFullConfiguration();
      
      expect(config, isNotEmpty);
      expect(config, contains('xhttp'));
      expect(config, contains('reality'));
      expect(config, contains('cdn.jsdelivr.net'));
    });
  });

  group('HTTPUpgrade URL Specific Tests', () {
    test('should correctly parse VLESS URL with httpupgrade transport', () {
      const vlessHttpupgradeUrl =
          'vless://e390c1ee-dffd-4a5d-82f5-a4a9a8ee4e80@69.84.182.90:8880?security=&encryption=none&host=suddhdussn.hide-abr.com.tr.&type=httpupgrade#%F0%9F%87%A9%F0%9F%87%AA%20%7C%20CDN';

      final vless = V2ray.parseFromURL(vlessHttpupgradeUrl);
      
      expect(vless.address, equals('69.84.182.90'));
      expect(vless.port, equals(8880));
      expect(vless.remark, equals('🇩🇪 | CDN'));
    });

    test('should generate correct httpupgrade stream settings', () {
      const vlessHttpupgradeUrl =
          'vless://e390c1ee-dffd-4a5d-82f5-a4a9a8ee4e80@69.84.182.90:8880?security=&encryption=none&host=suddhdussn.hide-abr.com.tr.&type=httpupgrade#%F0%9F%87%A9%F0%9F%87%AA%20%7C%20CDN';

      final vless = V2ray.parseFromURL(vlessHttpupgradeUrl);
      final streamSettings = vless.streamSetting;
      
      expect(streamSettings['network'], equals('httpupgrade'));
      expect(streamSettings['security'], equals(''));
      
      final httpupgradeSettings = streamSettings['httpupgradeSettings'] as Map;
      expect(httpupgradeSettings['host'], equals('suddhdussn.hide-abr.com.tr.'));
      expect(httpupgradeSettings['path'], equals(''));
    });

    test('should generate complete httpupgrade configuration', () {
      const vlessHttpupgradeUrl =
          'vless://e390c1ee-dffd-4a5d-82f5-a4a9a8ee4e80@69.84.182.90:8880?security=&encryption=none&host=suddhdussn.hide-abr.com.tr.&type=httpupgrade#%F0%9F%87%A9%F0%9F%87%AA%20%7C%20CDN';

      final vless = V2ray.parseFromURL(vlessHttpupgradeUrl);
      final config = vless.getFullConfiguration();
      
      expect(config, isNotEmpty);
      expect(config, contains('httpupgrade'));
      expect(config, contains('suddhdussn.hide-abr.com.tr.'));
    });
  });
}