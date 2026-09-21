using System.Collections.ObjectModel;
using CajaClara.Core;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Data;
using global::Windows.System;

namespace CajaClara.Windows;

public sealed partial class MainWindow
{
    private UIElement BuildPos()
    {
        var state = vm.Snapshot ?? throw new BusinessException("No hay sesión.");
        var panel = Column(18);
        panel.Children.Add(Body(state.Cash is null ? "Abrí un turno en Caja para empezar a vender." : "Escaneá un código y presioná Enter. F4 para cobrar."));
        var left = Column(); searchBox = Input("Buscar por nombre, código o lector de barras");
        var categories = new ComboBox { Header = "Categoría", HorizontalAlignment = HorizontalAlignment.Stretch };
        categories.Items.Add("Todas"); foreach (var category in state.Products.Select(x => x.Category).Distinct().Order()) categories.Items.Add(category); categories.SelectedIndex = 0;
        var products = new ListView { Height = 410, SelectionMode = ListViewSelectionMode.Single, DisplayMemberPath = "Display", IsItemClickEnabled = true };
        void Filter()
        {
            var query = searchBox.Text.Trim(); var category = categories.SelectedItem?.ToString();
            products.ItemsSource = (vm.Snapshot?.Products ?? []).Where(x => x.Active &&
                (string.IsNullOrWhiteSpace(query) || x.Name.Contains(query, StringComparison.OrdinalIgnoreCase) || x.Code.Contains(query, StringComparison.OrdinalIgnoreCase) || x.Barcode.Contains(query, StringComparison.OrdinalIgnoreCase)) &&
                (category is null or "Todas" || x.Category == category)).OrderBy(x => x.Name).ToArray();
        }
        searchBox.TextChanged += (_, _) => Filter(); categories.SelectionChanged += (_, _) => Filter();
        searchBox.KeyDown += async (_, e) =>
        {
            if (e.Key != VirtualKey.Enter || dialogOpen) return; e.Handled = true;
            await Run(() =>
            {
                var code = searchBox.Text.Trim(); var match = vm.Snapshot?.Products.FirstOrDefault(x => x.Barcode == code || x.Code.Equals(code, StringComparison.OrdinalIgnoreCase));
                if (match is null) match = (products.ItemsSource as Product[]) is { Length: 1 } found ? found[0] : products.SelectedItem as Product;
                if (match is null) throw new BusinessException("No se encontró un producto único. Seleccionalo o cargalo en Productos.");
                vm.Add(match); searchBox.Text = ""; Filter(); return Task.CompletedTask;
            });
        };
        products.DoubleTapped += async (_, _) => await Run(() => { if (products.SelectedItem is Product p) vm.Add(p); return Task.CompletedTask; });
        left.Children.Add(searchBox); left.Children.Add(categories); left.Children.Add(products);
        left.Children.Add(Button("Agregar seleccionado", () => { if (products.SelectedItem is not Product p) throw new BusinessException("Seleccioná un producto."); vm.Add(p); return Task.CompletedTask; }, true));
        var right = Column(); right.Children.Add(Heading("Venta actual", 22));
        customerBox = new ComboBox { Header = "Cliente · F2", ItemsSource = state.Contacts.Where(x => !x.Supplier).OrderBy(x => x.Name).ToArray(), DisplayMemberPath = "Display", HorizontalAlignment = HorizontalAlignment.Stretch };
        cartList = new ListView { ItemsSource = vm.Cart, DisplayMemberPath = "Display", Height = 290, SelectionMode = ListViewSelectionMode.Single };
        var total = Heading(vm.TotalText, 36); total.SetBinding(TextBlock.TextProperty, new Binding { Source = vm, Path = new PropertyPath(nameof(MainViewModel.TotalText)), Mode = BindingMode.OneWay });
        var caption = Body(vm.CartCaption); caption.SetBinding(TextBlock.TextProperty, new Binding { Source = vm, Path = new PropertyPath(nameof(MainViewModel.CartCaption)), Mode = BindingMode.OneWay });
        saleNotes = Input("Nota de la venta (opcional)"); fiscalPending = new CheckBox { Content = "Registrar facturación pendiente (no emite factura)" };
        right.Children.Add(customerBox); right.Children.Add(cartList);
        right.Children.Add(Row(Button("Cantidad / descuento · F6", EditCartAsync), Button("Quitar", () => { if (cartList.SelectedItem is CartItem item) vm.Remove(item); return Task.CompletedTask; })));
        right.Children.Add(saleNotes); right.Children.Add(fiscalPending); right.Children.Add(caption); right.Children.Add(total);
        right.Children.Add(Row(Button("Cobrar · F4", PayAsync, true), Button("Nueva · F8", NewSaleAsync)));
        var columns = new Grid { ColumnSpacing = 18, RowSpacing = 18 };
        columns.ColumnDefinitions.Add(new() { Width = new(1, GridUnitType.Star) }); columns.ColumnDefinitions.Add(new() { Width = new(1, GridUnitType.Star) });
        columns.RowDefinitions.Add(new() { Height = GridLength.Auto }); columns.RowDefinitions.Add(new() { Height = GridLength.Auto });
        var leftCard = Card(left); var rightCard = Card(right); columns.Children.Add(leftCard); columns.Children.Add(rightCard); Grid.SetColumn(rightCard, 1);
        columns.SizeChanged += (_, e) =>
        {
            var narrow = e.NewSize.Width < 930; Grid.SetColumn(rightCard, narrow ? 0 : 1); Grid.SetRow(rightCard, narrow ? 1 : 0);
            columns.ColumnDefinitions[1].Width = narrow ? new GridLength(0) : new GridLength(1, GridUnitType.Star);
        };
        panel.Children.Add(columns); Filter(); return panel;
    }
    private async Task NewSaleAsync()
    {
        if (vm.Cart.Count == 0 || await ConfirmAsync("Descartar carrito", "Los productos del carrito no se vendieron. ¿Iniciar una venta nueva?", "Descartar"))
        { vm.NewSale(); if (saleNotes is not null) saleNotes.Text = ""; if (customerBox is not null) customerBox.SelectedIndex = -1; }
    }
    private async Task EditCartAsync()
    {
        if (cartList?.SelectedItem is not CartItem line) throw new BusinessException("Seleccioná una línea del carrito.");
        var quantity = Input("Cantidad", (line.QuantityMilli / 1000m).ToString("0.###", Money.Culture));
        var discount = Input("Descuento total en pesos", DecimalText(line.DiscountCents));
        var price = Input("Precio unitario en pesos", DecimalText(line.OverridePriceCents ?? line.Product.PriceCents));
        discount.IsEnabled = vm.CanManage; price.IsEnabled = vm.CanManage;
        await FormAsync(line.Product.Name, Column(quantity, discount, price), () =>
        {
            if (!decimal.TryParse(quantity.Text, System.Globalization.NumberStyles.Number, Money.Culture, out var qty)) throw new BusinessException("Cantidad inválida.");
            var amount = Money.Quantity(qty); var rebate = Amount(discount); var unit = Amount(price, false);
            long? custom = unit == line.Product.PriceCents ? null : unit;
            SaleMath.Line(line.Product, new SaleInput(line.Product.Id, line.Product.Version, amount, rebate, custom), vm.CanManage);
            line.Change(amount, rebate, custom); vm.CartChanged(); return Task.CompletedTask;
        });
    }
    private async Task PayAsync()
    {
        if (!vm.CanSell || vm.Cart.Count == 0) throw new BusinessException("Agregá productos para cobrar.");
        if (vm.Snapshot?.Cash is null) throw new BusinessException("La caja está cerrada.");
        var total = vm.TotalCents; var payments = new ObservableCollection<Tender>();
        var method = new ComboBox { Header = "Medio de pago", ItemsSource = Enum.GetValues<PaymentMethod>(), SelectedIndex = 0, HorizontalAlignment = HorizontalAlignment.Stretch };
        var applied = Input("Importe aplicado a la venta", DecimalText(total)); var received = Input("Importe recibido", DecimalText(total)); var reference = Input("Referencia del banco / comprobante");
        var manual = new CheckBox { Content = "Verifiqué el cobro electrónico fuera de Caja Clara" };
        var paymentList = new ListView { ItemsSource = payments, Height = 120 };
        var info = Body("Falta cubrir " + Money.Format(total)); var localError = Body("");
        var add = new Button { Content = "Agregar medio de pago" };
        add.Click += (_, _) =>
        {
            try
            {
                if (method.SelectedItem is not PaymentMethod selected) throw new BusinessException("Elegí un medio.");
                var value = Amount(applied, false); var taken = Amount(received, false);
                if (selected != PaymentMethod.Cash && manual.IsChecked != true) throw new BusinessException("Confirmá que verificaste el cobro en el banco o terminal.");
                var tender = new Tender(selected, value, taken, reference.Text.Trim());
                SaleMath.ValidatePayments(value, [tender]);
                if (payments.Sum(x => x.AppliedCents) + value > total) throw new BusinessException("El pago supera lo pendiente. El excedente de efectivo va en Importe recibido.");
                payments.Add(tender); var remaining = total - payments.Sum(x => x.AppliedCents);
                applied.Text = DecimalText(remaining); received.Text = DecimalText(remaining); reference.Text = ""; manual.IsChecked = false;
                info.Text = "Pendiente: " + Money.Format(remaining) + " · Vuelto: " + Money.Format(payments.Sum(x => x.ChangeCents)); localError.Text = "";
            }
            catch (BusinessException e) { localError.Text = e.Message; }
        };
        var remove = new Button { Content = "Quitar seleccionado" };
        remove.Click += (_, _) => { if (paymentList.SelectedItem is Tender tender) payments.Remove(tender); var remaining = total - payments.Sum(x => x.AppliedCents); applied.Text = DecimalText(remaining); received.Text = DecimalText(remaining); info.Text = "Pendiente: " + Money.Format(remaining); };
        var form = Column(Heading(Money.Format(total), 34), Body("Los medios electrónicos se registran manualmente. Caja Clara no confirma ni debita fondos en esta pantalla."), method, applied, received, reference, manual, Row(add, remove), paymentList, info, localError);
        Sale? confirmed = null;
        var success = await FormAsync("Cobrar venta", form, async () =>
        {
            if (payments.Count == 0) throw new BusinessException("Agregá al menos un medio de pago.");
            confirmed = await vm.CheckoutAsync((customerBox?.SelectedItem as Contact)?.Id, payments.ToArray(), saleNotes?.Text ?? "", fiscalPending?.IsChecked == true);
        }, "Confirmar venta");
        if (success && confirmed is not null)
        {
            await Navigate("pos"); Notify($"Venta #{confirmed.Number:000000} guardada. Vuelto: {Money.Format(confirmed.ChangeCents)}. El comprobante está en Ventas.");
        }
    }
    private UIElement BuildDashboard()
    {
        var state = vm.Snapshot ?? throw new BusinessException("Sin datos."); var today = DateTimeOffset.Now.Date;
        var sales = state.Sales.Where(x => x.At.ToLocalTime().Date == today).ToArray(); var gross = sales.Sum(x => x.TotalCents);
        var panel = Column(20); panel.Children.Add(Heading(state.Business?.Name ?? "Tu comercio", 30));
        panel.Children.Add(Body("Resumen comercial del día. La facturación autorizada se muestra por separado."));
        var cards = new Grid { ColumnSpacing = 12, RowSpacing = 12 };
        cards.ColumnDefinitions.Add(new() { Width = new(1, GridUnitType.Star) }); cards.ColumnDefinitions.Add(new() { Width = new(1, GridUnitType.Star) });
        cards.RowDefinitions.Add(new()); cards.RowDefinitions.Add(new());
        var metrics = new[] { ("Ventas brutas hoy", Money.Format(gross)), ("Operaciones", sales.Length.ToString()),
            ("Ticket promedio", Money.Format(sales.Length == 0 ? 0 : gross / sales.Length)), ("Autorizado fiscal", Money.Format(sales.Where(x => x.FiscalState == FiscalState.Authorized).Sum(x => x.TotalCents))) };
        for (var i = 0; i < metrics.Length; i++) { var card = Card(Column(Body(metrics[i].Item1), Heading(metrics[i].Item2, 30))); Grid.SetRow(card, i / 2); Grid.SetColumn(card, i % 2); cards.Children.Add(card); }
        panel.Children.Add(cards);
        panel.Children.Add(Card(Column(Heading("Últimas ventas", 20), new ListView { ItemsSource = sales.OrderByDescending(x => x.At).Take(10).ToArray(), DisplayMemberPath = "Display", MaxHeight = 280 })));
        var low = state.Products.Where(x => x.LowStock).ToArray();
        panel.Children.Add(Card(Column(Heading($"Stock bajo · {low.Length}", 20), new ListView { ItemsSource = low, DisplayMemberPath = "Display", MaxHeight = 240 })));
        foreach (var alert in state.Notifications.Where(x => !x.Read).Take(10))
        {
            var captured = alert;
            panel.Children.Add(Card(Column(Heading(alert.Title, 18), Body(alert.Detail), Button("Marcar leído", async () => { await Task.Run(() => vm.Pos.MarkNotificationRead(vm.User, captured.Id)); await Navigate("dashboard"); }))));
        }
        return panel;
    }
    private UIElement BuildCash()
    {
        var panel = Column(20); var cash = vm.Snapshot?.Cash;
        panel.Children.Add(Card(Column(Heading(cash is null ? "Caja cerrada" : cash.State == CashState.ClosingRequested ? "Cierre solicitado por el dueño" : "Caja abierta", 28),
            Body(cash is null ? "Ingresá el efectivo inicial para comenzar el turno." : $"Apertura {cash.OpenedAt.ToLocalTime():dd/MM/yyyy HH:mm} · Efectivo inicial {Money.Format(cash.OpeningCents)}"),
            Heading(cash is null ? Money.Format(0) : Money.Format(cash.ExpectedCents), 38), Body("Efectivo esperado. No incluye transferencias ni tarjetas."))));
        if (!vm.CanSell) { panel.Children.Add(Body("Tu usuario tiene acceso de consulta.")); return panel; }
        panel.Children.Add(Row(Button("Abrir caja", async () =>
        {
            var amount = Input("Efectivo inicial", "0,00"); var notes = Input("Observaciones");
            if (await FormAsync("Apertura de caja", Column(amount, notes), async () => { var value = Amount(amount); var note = notes.Text; await Task.Run(() => vm.Pos.OpenRegister(vm.User, value, note)); })) await Navigate("cash");
        }, cash is null), Button("Cerrar turno", async () =>
        {
            if (vm.Snapshot?.Cash is not CashSession current) throw new BusinessException("La caja ya está cerrada.");
            var amount = Input("Efectivo contado"); var notes = Input("Observaciones del cierre"); CashSession? closed = null;
            if (await FormAsync("Cierre de caja", Column(Body("Contá el efectivo físico. El cierre no se puede editar posteriormente."), amount, notes), async () =>
            { var counted = Amount(amount); var note = notes.Text; closed = await Task.Run(() => vm.Pos.CloseRegister(vm.User, counted, note)); }, "Cerrar caja"))
            { await Navigate("cash"); Notify("Cierre guardado. Diferencia: " + Money.Format(closed?.DifferenceCents ?? 0)); }
        })));
        panel.Children.Add(Row(Button("Ingreso / gasto / retiro", async () =>
        {
            var kind = new ComboBox { Header = "Tipo", ItemsSource = new[] { "INCOME", "EXPENSE", "WITHDRAWAL" }, SelectedIndex = 1, MinWidth = 240 };
            var amount = Input("Importe"); var reason = Input("Motivo obligatorio");
            if (await FormAsync("Movimiento de efectivo", Column(kind, amount, reason), async () =>
            { var value = Amount(amount, false); var type = kind.SelectedItem?.ToString() ?? ""; var detail = reason.Text; await Task.Run(() => vm.Pos.RecordCashMovement(vm.User, value, type, detail)); })) await Navigate("cash");
        })));
        if (vm.CanManage)
        {
            var history = vm.Pos.History<CashSession>(vm.User).OrderByDescending(x => x.OpenedAt).ToArray();
            var list = new ListView { ItemsSource = history, DisplayMemberPath = "Display", Height = 260 };
            panel.Children.Add(Heading("Turnos anteriores", 20)); panel.Children.Add(list);
            panel.Children.Add(Button("Exportar cierre seleccionado a PDF", async () =>
            {
                if (list.SelectedItem is not CashSession session || session.State != CashState.Closed) throw new BusinessException("Seleccioná un turno cerrado.");
                var path = await SavePathAsync("Cierre-" + session.OpenedAt.ToString("yyyyMMdd-HHmm"), ".pdf"); if (path is null) return;
                var lines = new[] { vm.Snapshot?.Business?.Name ?? "Caja Clara", "CIERRE DE CAJA - INFORME INTERNO", "Apertura: " + session.OpenedAt.ToLocalTime(), "Cierre: " + session.ClosedAt?.ToLocalTime(), "Inicial: " + Money.Format(session.OpeningCents), "Esperado: " + Money.Format(session.ExpectedCents), "Contado: " + Money.Format(session.CountedCents ?? 0), "Diferencia: " + Money.Format(session.DifferenceCents ?? 0), "Observaciones: " + session.Notes, "ID: " + session.Id };
                await Task.Run(() => Receipt.Pdf(path, lines, 210)); Launch(path);
            }));
        }
        return panel;
    }
    private UIElement BuildSales()
    {
        var list = new ListView { ItemsSource = vm.Snapshot?.Sales.OrderByDescending(x => x.At).ToArray(), DisplayMemberPath = "Display", Height = 480 };
        Sale Selected() => list.SelectedItem as Sale ?? throw new BusinessException("Seleccioná una venta.");
        var panel = Column(18); panel.Children.Add(Body("Las ventas confirmadas no se eliminan. Las correcciones quedan registradas como devoluciones.")); panel.Children.Add(list);
        panel.Children.Add(Row(Button("Ver comprobante", async () =>
        {
            var sale = Selected(); var business = vm.Snapshot?.Business ?? throw new BusinessException("Sin comercio.");
            await FormAsync($"Venta #{sale.Number}", Column(Body(string.Join(Environment.NewLine, Receipt.Lines(business, sale, 52)))), () => Task.CompletedTask, "Cerrar");
        }), Button("Guardar PDF", async () =>
        {
            var sale = Selected(); var business = vm.Snapshot?.Business ?? throw new BusinessException("Sin comercio.");
            var path = await SavePathAsync("Venta-" + sale.Number.ToString("000000"), ".pdf"); if (path is null) return;
            await Task.Run(() => Receipt.Pdf(path, Receipt.Lines(business, sale), 80)); Launch(path);
        }), Button("Imprimir", async () =>
        {
            var sale = Selected(); var business = vm.Snapshot?.Business ?? throw new BusinessException("Sin comercio.");
            var settings = PrinterPreferences.Load();
            if (!await ConfirmAsync("Imprimir comprobante interno", $"Impresora: {settings.PrinterName}. Ancho: {settings.WidthMm} mm. Este documento no es una factura fiscal.", "Enviar a impresora")) return;
            await Task.Run(() => WindowsPrinter.Print(Receipt.Lines(business, sale), settings)); Notify("Comprobante enviado a la cola de impresión. Verificá la salida física.");
        })));
        if (vm.CanManage) panel.Children.Add(Button("Registrar devolución total", async () =>
        {
            var sale = Selected(); var reason = Input("Motivo obligatorio");
            var consent = new CheckBox { Content = "Recibí la mercadería y devolví el dinero por los medios originales" };
            var request = Guid.NewGuid();
            if (await FormAsync("Devolver venta #" + sale.Number, Column(Body("Se devolverá el stock y se registrará la salida de efectivo. Los reembolsos bancarios deben realizarse fuera de Caja Clara. La factura original, si existe, requiere su tratamiento fiscal separado."), reason, consent), async () =>
            {
                if (consent.IsChecked != true) throw new BusinessException("Confirmá la devolución de mercadería y dinero.");
                var detail = reason.Text; await Task.Run(() => vm.Pos.RefundSale(vm.User, request, sale.Id, detail));
            }, "Registrar devolución")) { await Navigate("sales"); Notify("Devolución registrada con auditoría."); }
        }));
        return panel;
    }
}
