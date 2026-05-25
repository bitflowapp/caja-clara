// Internal developer-only demo catalog. Not imported by production code.
// Edit this file to change what gets seeded by seed_demo_data.dart.

class DemoProductSeed {
  const DemoProductSeed({
    required this.name,
    required this.category,
    required this.pricePesos,
    this.barcode,
    this.isFavorite = false,
    this.stockUnits = 20,
    this.minStockUnits = 5,
  });

  final String name;
  final String category;
  final int pricePesos;
  final String? barcode;
  final bool isFavorite;
  final int stockUnits;
  final int minStockUnits;
}

// Barcode to test the "unknown product" scan flow in demos.
const String kDemoUnknownBarcode = '991122334455';

// Absolute path to the Coca-Cola image for visual signature seeding.
// If the file doesn't exist the tool skips the signature step gracefully.
const String kDemoColaImagePath =
    r'C:\1212\D_NQ_NP_2X_663842-MLA53151984915_012023-F.webp';

// Normalized barcode for the Coca-Cola product (strips non-alphanumeric).
const String kDemoColaNormalizedBarcode = '7790001000011';

const int kDemoCashOpeningPesos = 10000;

const String kDemoExpenseConcept = 'Pago proveedor bebidas';
const int kDemoExpensePesos = 5000;
const String kDemoExpenseCategory = 'Proveedor';

const List<DemoProductSeed> kDemoCatalog = [
  DemoProductSeed(
    name: 'Coca-Cola 2.25 L',
    category: 'Bebidas',
    pricePesos: 3500,
    barcode: '7790001000011',
    isFavorite: true,
    stockUnits: 24,
    minStockUnits: 6,
  ),
  DemoProductSeed(
    name: 'Pepsi 2.25 L',
    category: 'Gaseosas',
    pricePesos: 3200,
    barcode: '7790001000028',
    stockUnits: 12,
    minStockUnits: 4,
  ),
  DemoProductSeed(
    name: 'Sprite 1.5 L',
    category: 'Gaseosas',
    pricePesos: 2800,
    barcode: '7790001000035',
    stockUnits: 12,
    minStockUnits: 4,
  ),
  DemoProductSeed(
    name: 'Agua mineral 1.5 L',
    category: 'Bebidas',
    pricePesos: 1400,
    barcode: '7790001000042',
    isFavorite: true,
    stockUnits: 18,
    minStockUnits: 6,
  ),
  DemoProductSeed(
    name: 'Alfajor Jorgito',
    category: 'Alfajores',
    pricePesos: 800,
    isFavorite: true,
    stockUnits: 30,
    minStockUnits: 10,
  ),
  DemoProductSeed(
    name: 'Alfajor Havanna x2',
    category: 'Alfajores',
    pricePesos: 2100,
    barcode: '7670001000010',
    stockUnits: 12,
    minStockUnits: 4,
  ),
  DemoProductSeed(
    name: 'Galletitas Oreo',
    category: 'Snacks',
    pricePesos: 1600,
    barcode: '7790001000056',
    stockUnits: 6,
    minStockUnits: 3,
  ),
  DemoProductSeed(
    name: 'Papas fritas Lays',
    category: 'Snacks',
    pricePesos: 1200,
    barcode: '7790001000063',
    stockUnits: 18,
    minStockUnits: 5,
  ),
  DemoProductSeed(
    name: 'Mani salado',
    category: 'Snacks',
    pricePesos: 900,
    stockUnits: 15,
    minStockUnits: 5,
  ),
  DemoProductSeed(
    name: 'Cigarrillos Marlboro',
    category: 'Cigarrillos',
    pricePesos: 2200,
    barcode: '7790001000077',
    isFavorite: true,
    stockUnits: 20,
    minStockUnits: 5,
  ),
  DemoProductSeed(
    name: 'Cigarrillos Lucky Strike',
    category: 'Cigarrillos',
    pricePesos: 2100,
    barcode: '7790001000084',
    stockUnits: 20,
    minStockUnits: 5,
  ),
  DemoProductSeed(
    name: 'Cerveza Quilmes 1 L',
    category: 'Alcohol',
    pricePesos: 2600,
    barcode: '7790001000091',
    stockUnits: 12,
    minStockUnits: 4,
  ),
  DemoProductSeed(
    name: 'Vino tinto 750 ml',
    category: 'Alcohol',
    pricePesos: 4200,
    barcode: '7790001000107',
    stockUnits: 8,
    minStockUnits: 2,
  ),
  DemoProductSeed(
    name: 'Fernet 750 ml',
    category: 'Alcohol',
    pricePesos: 8900,
    barcode: '7790001000114',
    stockUnits: 6,
    minStockUnits: 2,
  ),
  DemoProductSeed(
    name: 'Jabon en polvo 500 g',
    category: 'Limpieza',
    pricePesos: 1800,
    barcode: '7790001000121',
    stockUnits: 10,
    minStockUnits: 3,
  ),
  DemoProductSeed(
    name: 'Lavandina 1 L',
    category: 'Limpieza',
    pricePesos: 1100,
    barcode: '7790001000138',
    stockUnits: 12,
    minStockUnits: 4,
  ),
  DemoProductSeed(
    name: 'Papel higienico x4',
    category: 'Limpieza',
    pricePesos: 2900,
    barcode: '7790001000145',
    stockUnits: 8,
    minStockUnits: 3,
  ),
  DemoProductSeed(
    name: 'Chicles Beldent',
    category: 'Varios',
    pricePesos: 400,
    stockUnits: 24,
    minStockUnits: 8,
  ),
  DemoProductSeed(
    name: 'Encendedor',
    category: 'Varios',
    pricePesos: 700,
    stockUnits: 15,
    minStockUnits: 5,
  ),
  DemoProductSeed(
    name: 'Servilletas x100',
    category: 'Varios',
    pricePesos: 600,
    stockUnits: 10,
    minStockUnits: 3,
  ),
];
