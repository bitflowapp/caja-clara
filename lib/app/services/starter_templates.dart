class StarterTemplateProductSeed {
  const StarterTemplateProductSeed({
    required this.name,
    required this.category,
    this.stockUnits = 0,
    this.minStockUnits = 3,
    this.costPesos = 0,
    this.pricePesos = 0,
  });

  final String name;
  final String category;
  final int stockUnits;
  final int minStockUnits;
  final int costPesos;
  final int pricePesos;
}

const String argentinianKioskTemplateName = 'Kiosco argentino';

const List<StarterTemplateProductSeed> argentinianKioskTemplateProducts =
    <StarterTemplateProductSeed>[
      StarterTemplateProductSeed(
        name: 'Agua 500 ml',
        category: 'Bebidas sin alcohol',
      ),
      StarterTemplateProductSeed(
        name: 'Agua 1.5 L',
        category: 'Bebidas sin alcohol',
      ),
      StarterTemplateProductSeed(
        name: 'Coca-Cola 500 ml',
        category: 'Bebidas sin alcohol',
      ),
      StarterTemplateProductSeed(
        name: 'Coca-Cola 1.5 L',
        category: 'Bebidas sin alcohol',
      ),
      StarterTemplateProductSeed(
        name: 'Pepsi 500 ml',
        category: 'Bebidas sin alcohol',
      ),
      StarterTemplateProductSeed(
        name: 'Sprite 500 ml',
        category: 'Bebidas sin alcohol',
      ),
      StarterTemplateProductSeed(
        name: 'Fanta 500 ml',
        category: 'Bebidas sin alcohol',
      ),
      StarterTemplateProductSeed(
        name: 'Speed lata',
        category: 'Bebidas sin alcohol',
      ),
      StarterTemplateProductSeed(
        name: 'Monster lata',
        category: 'Bebidas sin alcohol',
      ),
      StarterTemplateProductSeed(
        name: 'Jugo individual',
        category: 'Bebidas sin alcohol',
      ),
      StarterTemplateProductSeed(
        name: 'Agua saborizada',
        category: 'Bebidas sin alcohol',
      ),
      StarterTemplateProductSeed(name: 'Yerba mate', category: 'Almacen'),
      StarterTemplateProductSeed(name: 'Café', category: 'Almacen'),
      StarterTemplateProductSeed(name: 'Leche', category: 'Almacen'),
      StarterTemplateProductSeed(name: 'Pan', category: 'Almacen'),
      StarterTemplateProductSeed(name: 'Arroz', category: 'Almacen'),
      StarterTemplateProductSeed(name: 'Azúcar', category: 'Almacen'),
      StarterTemplateProductSeed(name: 'Hielo bolsa', category: 'Hielo'),
      StarterTemplateProductSeed(name: 'Alfajor simple', category: 'Golosinas'),
      StarterTemplateProductSeed(name: 'Alfajor triple', category: 'Golosinas'),
      StarterTemplateProductSeed(
        name: 'Chocolate barra',
        category: 'Golosinas',
      ),
      StarterTemplateProductSeed(name: 'Chicles', category: 'Golosinas'),
      StarterTemplateProductSeed(name: 'Caramelos', category: 'Golosinas'),
      StarterTemplateProductSeed(name: 'Gomitas', category: 'Golosinas'),
      StarterTemplateProductSeed(name: 'Turron', category: 'Golosinas'),
      StarterTemplateProductSeed(name: 'Oblea', category: 'Golosinas'),
      StarterTemplateProductSeed(name: 'Papas fritas', category: 'Snacks'),
      StarterTemplateProductSeed(name: 'Palitos salados', category: 'Snacks'),
      StarterTemplateProductSeed(name: 'Mani', category: 'Snacks'),
      StarterTemplateProductSeed(name: 'Mix snack', category: 'Snacks'),
      StarterTemplateProductSeed(name: 'Nachos', category: 'Snacks'),
      StarterTemplateProductSeed(name: 'Aceite', category: 'Almacen'),
      StarterTemplateProductSeed(
        name: 'Cuaderno',
        category: 'Libreria',
      ),
      StarterTemplateProductSeed(
        name: 'Lapicera',
        category: 'Libreria',
      ),
      StarterTemplateProductSeed(
        name: 'Galletitas dulces',
        category: 'Galletitas y kiosco dulce',
      ),
      StarterTemplateProductSeed(
        name: 'Galletitas saladas',
        category: 'Galletitas y kiosco dulce',
      ),
      StarterTemplateProductSeed(
        name: 'Bizcochos',
        category: 'Galletitas y kiosco dulce',
      ),
      StarterTemplateProductSeed(
        name: 'Budin individual',
        category: 'Galletitas y kiosco dulce',
      ),
      StarterTemplateProductSeed(
        name: 'Panuelitos',
        category: 'Higiene rapida / impulso',
      ),
      StarterTemplateProductSeed(
        name: 'Servilletas',
        category: 'Higiene rapida / impulso',
      ),
      StarterTemplateProductSeed(
        name: 'Desodorante chico',
        category: 'Higiene rapida / impulso',
      ),
      StarterTemplateProductSeed(
        name: 'Jabón de tocador',
        category: 'Higiene rapida / impulso',
      ),
      StarterTemplateProductSeed(
        name: 'Pilas AA',
        category: 'Accesorios de mostrador',
      ),
      StarterTemplateProductSeed(
        name: 'Pilas AAA',
        category: 'Accesorios de mostrador',
      ),
      StarterTemplateProductSeed(
        name: 'Cargador USB básico',
        category: 'Accesorios de mostrador',
      ),
      StarterTemplateProductSeed(
        name: 'Cable USB básico',
        category: 'Accesorios de mostrador',
      ),
    ];
