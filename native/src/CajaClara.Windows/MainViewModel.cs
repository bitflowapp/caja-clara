using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using CajaClara.Core;

namespace CajaClara.Windows;

public sealed class CartItem(Product product, long quantityMilli) : INotifyPropertyChanged
{
    public Product Product { get; private set; } = product;
    public long QuantityMilli { get; private set; } = quantityMilli;
    public long DiscountCents { get; private set; }
    public long? OverridePriceCents { get; private set; }
    public long Total => Money.Extend(OverridePriceCents ?? Product.PriceCents, QuantityMilli) - DiscountCents;
    public string Display => $"{Product.Name}\n{QuantityMilli / 1000m:0.###} {Product.Unit} × {Money.Format(OverridePriceCents ?? Product.PriceCents)}   ·   {Money.Format(Total)}" + (DiscountCents > 0 ? "  (con descuento)" : "");
    public SaleInput Input => new(Product.Id, Product.Version, QuantityMilli, DiscountCents, OverridePriceCents);
    public void Change(long quantity, long discount, long? price)
    {
        QuantityMilli = quantity; DiscountCents = discount; OverridePriceCents = price;
        PropertyChanged?.Invoke(this, new(nameof(Display))); PropertyChanged?.Invoke(this, new(nameof(Total)));
    }
    public event PropertyChangedEventHandler? PropertyChanged;
}
public sealed class MainViewModel(Store store, AuthService auth, PosService pos, Reports reports) : INotifyPropertyChanged
{
    public Store Store { get; } = store;
    public AuthService Auth { get; } = auth;
    public PosService Pos { get; } = pos;
    public Reports Reports { get; } = reports;
    public Actor? Actor { get; private set; }
    public Snapshot? Snapshot { get; private set; }
    public ObservableCollection<CartItem> Cart { get; } = [];
    public Guid SaleRequestId { get; private set; } = Guid.NewGuid();
    public Actor User => Actor ?? throw new BusinessException("Iniciá sesión.");
    public bool CanManage => Actor?.Role is Role.Owner or Role.Admin;
    public bool CanSell => Actor?.Role is Role.Owner or Role.Admin or Role.Cashier;
    public long TotalCents => Cart.Sum(x => x.Total);
    public string TotalText => Money.Format(TotalCents);
    public string CartCaption => $"{Cart.Count} productos · Total";
    public async Task LoginAsync(string username, string password)
    { Actor = await Task.Run(() => Auth.Authenticate(username, password)); await RefreshAsync(); }
    public async Task BootstrapAsync(string business, string name, string username, string password)
    {
        Actor = await Task.Run(() => Auth.Bootstrap(business, name, username, password, Environment.GetCommandLineArgs().Contains("--demo")));
        await RefreshAsync();
    }
    public async Task RefreshAsync()
    {
        Snapshot = await Task.Run(() => Pos.Snapshot(User));
        Changed(nameof(Snapshot)); Changed(nameof(CanManage)); Changed(nameof(CanSell));
    }
    public void Add(Product product)
    {
        if (!CanSell) throw new BusinessException("Tu usuario no puede registrar ventas.");
        if (!product.Active) throw new BusinessException("Producto pausado.");
        var current = Cart.SingleOrDefault(x => x.Product.Id == product.Id);
        var quantity = (current?.QuantityMilli ?? 0) + 1000;
        if (quantity > product.StockMilli) throw new BusinessException("Stock insuficiente. Para productos fraccionados editá la cantidad.");
        if (current is null) Cart.Add(new CartItem(product, 1000)); else current.Change(quantity, current.DiscountCents, current.OverridePriceCents);
        CartChanged();
    }
    public void Remove(CartItem item) { Cart.Remove(item); CartChanged(); }
    public void CartChanged() { Changed(nameof(TotalText)); Changed(nameof(CartCaption)); Changed(nameof(TotalCents)); }
    public void NewSale() { Cart.Clear(); SaleRequestId = Guid.NewGuid(); CartChanged(); }
    public async Task<Sale> CheckoutAsync(Guid? customerId, Tender[] payments, string notes, bool fiscal)
    {
        var request = new CheckoutRequest(SaleRequestId, customerId, Cart.Select(x => x.Input).ToArray(), payments, notes, fiscal);
        var sale = await Task.Run(() => Pos.Checkout(User, request)); NewSale(); await RefreshAsync(); return sale;
    }
    public void Logout() { Actor = null; Snapshot = null; NewSale(); }
    public event PropertyChangedEventHandler? PropertyChanged;
    private void Changed([CallerMemberName] string? property = null) => PropertyChanged?.Invoke(this, new(property));
}
