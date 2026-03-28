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
const List<String> suggestedArgentinianProductCategories = <String>[
  'Bebidas',
  'Golosinas',
  'Galletitas',
  'Almacen',
  'Limpieza',
  'Perfumeria',
  'Cigarrillos',
  'Otros',
];

const List<StarterTemplateProductSeed>
argentinianKioskTemplateProducts = <StarterTemplateProductSeed>[
  StarterTemplateProductSeed(name: 'Agua 500 ml', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Agua 1.5 L', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Coca-Cola 500 ml', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Coca-Cola 1.5 L', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Pepsi 500 ml', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Sprite 500 ml', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Fanta 500 ml', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Speed lata', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Monster lata', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Jugo individual', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Agua saborizada', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Cerveza lata 473 ml', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Cerveza litro', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Fernet botella', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Vodka chico', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Vino botella', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Vino tetra', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Hielo bolsa', category: 'Bebidas'),
  StarterTemplateProductSeed(name: 'Alfajor simple', category: 'Golosinas'),
  StarterTemplateProductSeed(name: 'Alfajor triple', category: 'Golosinas'),
  StarterTemplateProductSeed(name: 'Chocolate barra', category: 'Golosinas'),
  StarterTemplateProductSeed(name: 'Chicles', category: 'Golosinas'),
  StarterTemplateProductSeed(name: 'Caramelos', category: 'Golosinas'),
  StarterTemplateProductSeed(name: 'Gomitas', category: 'Golosinas'),
  StarterTemplateProductSeed(name: 'Turron', category: 'Golosinas'),
  StarterTemplateProductSeed(name: 'Oblea', category: 'Golosinas'),
  StarterTemplateProductSeed(name: 'Papas fritas', category: 'Golosinas'),
  StarterTemplateProductSeed(name: 'Palitos salados', category: 'Golosinas'),
  StarterTemplateProductSeed(name: 'Mani', category: 'Golosinas'),
  StarterTemplateProductSeed(name: 'Mix snack', category: 'Golosinas'),
  StarterTemplateProductSeed(name: 'Nachos', category: 'Golosinas'),
  StarterTemplateProductSeed(
    name: 'Cigarrillos Marlboro box',
    category: 'Cigarrillos',
  ),
  StarterTemplateProductSeed(
    name: 'Cigarrillos Philip Morris box',
    category: 'Cigarrillos',
  ),
  StarterTemplateProductSeed(
    name: 'Cigarrillos Lucky Strike box',
    category: 'Cigarrillos',
  ),
  StarterTemplateProductSeed(
    name: 'Cigarrillos Chesterfield box',
    category: 'Cigarrillos',
  ),
  StarterTemplateProductSeed(name: 'Encendedor comun', category: 'Cigarrillos'),
  StarterTemplateProductSeed(
    name: 'Encendedor recargable',
    category: 'Cigarrillos',
  ),
  StarterTemplateProductSeed(
    name: 'Pasta dental chica',
    category: 'Perfumeria',
  ),
  StarterTemplateProductSeed(name: 'Jabon de tocador', category: 'Perfumeria'),
  StarterTemplateProductSeed(name: 'Galletitas dulces', category: 'Galletitas'),
  StarterTemplateProductSeed(
    name: 'Galletitas saladas',
    category: 'Galletitas',
  ),
  StarterTemplateProductSeed(name: 'Bizcochos', category: 'Galletitas'),
  StarterTemplateProductSeed(name: 'Budin individual', category: 'Galletitas'),
  StarterTemplateProductSeed(name: 'Yerba 1 kg', category: 'Almacen'),
  StarterTemplateProductSeed(name: 'Azucar 1 kg', category: 'Almacen'),
  StarterTemplateProductSeed(name: 'Fideos secos', category: 'Almacen'),
  StarterTemplateProductSeed(name: 'Panuelitos', category: 'Perfumeria'),
  StarterTemplateProductSeed(
    name: 'Toallitas femeninas',
    category: 'Perfumeria',
  ),
  StarterTemplateProductSeed(name: 'Desodorante chico', category: 'Perfumeria'),
  StarterTemplateProductSeed(
    name: 'Alcohol en gel chico',
    category: 'Perfumeria',
  ),
  StarterTemplateProductSeed(name: 'Lavandina 1 L', category: 'Limpieza'),
  StarterTemplateProductSeed(name: 'Detergente 500 ml', category: 'Limpieza'),
  StarterTemplateProductSeed(name: 'Papel higienico x4', category: 'Limpieza'),
  StarterTemplateProductSeed(name: 'Pilas AA', category: 'Otros'),
  StarterTemplateProductSeed(name: 'Pilas AAA', category: 'Otros'),
  StarterTemplateProductSeed(name: 'Cargador USB basico', category: 'Otros'),
  StarterTemplateProductSeed(name: 'Cable USB basico', category: 'Otros'),
];
