import 'package:flutter_test/flutter_test.dart';
import 'package:msoft_vfd/features/products/screens/add_product_screen.dart';

// Same expectations as the web portal's sanitize-price.ts / sanitize-product-name.ts.
void main() {
  test('price', () {
    expect(sanitizePrice('1250'), '1250');
    expect(sanitizePrice('1,250.5'), '1250.5');
    expect(sanitizePrice('1250.505'), '1250.50');
    expect(sanitizePrice('.5'), '0.5');
    expect(sanitizePrice('12.3.4'), '12.34');
    expect(sanitizePrice('abc'), '');
  });
  test('product name', () {
    expect(sanitizeProductName('Coca-Cola 500ml'), 'CocaCola 500ml');
    expect(sanitizeProductName('  Rice@  1kg'), 'Rice 1kg');
    expect(sanitizeProductName('Unga wa Sembe '), 'Unga wa Sembe ');
    expect(sanitizeProductName('Chai ☕ 100g'), 'Chai 100g');
  });
}
