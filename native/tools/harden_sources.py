from pathlib import Path

root = Path(__file__).resolve().parents[1]
patches = {
 'src/CajaClara.Core/Application/Reports.cs': [
  ('var temporary = path + ".writing";', 'var temporary = path + ".writing.xlsx";'),
 ],
 'src/CajaClara.Core/Application/PosService.cs': [
  ('Convert.ToInt32(tx.Scalar("SELECT COUNT(*) FROM outbox WHERE sent_at IS NULL")), "ok");', 'Convert.ToInt32(tx.Scalar("SELECT COUNT(*) FROM outbox WHERE sent_at IS NULL")), "not_checked");'),
 ],
 'src/CajaClara.Core/Persistence/Store.cs': [
  ('if (version == 0)\n            {\n                var assembly', 'if (version == 0)\n            {\n                check.CommandText = "SELECT COUNT(*) FROM sqlite_master WHERE type=\'table\' AND name NOT LIKE \'sqlite_%\'";\n                if (Convert.ToInt32(check.ExecuteScalar()) != 0) throw new BusinessException("La base existente no pertenece a Caja Clara Native. No se modificó.");\n                var assembly'),
 ],
 'src/CajaClara.Windows/PosPages.cs': [
  ('await Task.Run(() => vm.Pos.OpenRegister(vm.User, Amount(amount), notes.Text));', 'var value = Amount(amount); var note = notes.Text; await Task.Run(() => vm.Pos.OpenRegister(vm.User, value, note));'),
  ('closed = await Task.Run(() => vm.Pos.CloseRegister(vm.User, Amount(amount), notes.Text));', 'var counted = Amount(amount); var note = notes.Text; closed = await Task.Run(() => vm.Pos.CloseRegister(vm.User, counted, note));'),
  ('await Task.Run(() => vm.Pos.RecordCashMovement(vm.User, Amount(amount, false), kind.SelectedItem.ToString() ?? "", reason.Text));', 'var value = Amount(amount, false); var type = kind.SelectedItem?.ToString() ?? ""; var detail = reason.Text; await Task.Run(() => vm.Pos.RecordCashMovement(vm.User, value, type, detail));'),
  ('await Task.Run(() => vm.Pos.RefundSale(vm.User, request, sale.Id, reason.Text));', 'var detail = reason.Text; await Task.Run(() => vm.Pos.RefundSale(vm.User, request, sale.Id, detail));'),
 ],
 'src/CajaClara.Windows/ManagementPages.cs': [
  ('await Task.Run(() => vm.Pos.AdjustStock(vm.User, new(p.Id, p.Version, delta, reason.Text)));', 'var adjustment = new StockAdjustment(p.Id, p.Version, delta, reason.Text); await Task.Run(() => vm.Pos.AdjustStock(vm.User, adjustment));'),
  ('await Task.Run(() => vm.Pos.SaveContact(vm.User, new Contact(id, (old?.Version ?? 0) + 1, name.Text, tax.Text, phone.Text, email.Text, address.Text, supplier.IsChecked == true, code), old?.Version ?? 0));', 'var contact = new Contact(id, (old?.Version ?? 0) + 1, name.Text, tax.Text, phone.Text, email.Text, address.Text, supplier.IsChecked == true, code); await Task.Run(() => vm.Pos.SaveContact(vm.User, contact, old?.Version ?? 0));'),
  ('await Task.Run(() => vm.Pos.ReceivePurchase(vm.User, id, selected.Id, lines.ToArray(), Amount(paid), reference.Text));', 'var items = lines.ToArray(); var amount = Amount(paid); var detail = reference.Text; await Task.Run(() => vm.Pos.ReceivePurchase(vm.User, id, selected.Id, items, amount, detail));'),
 ],
 'src/CajaClara.Windows/SettingsPages.cs': [
  ('await Task.Run(() => vm.Auth.SetPin(vm.User, pin.Password)); pin.Password = "";', 'var value = pin.Password; await Task.Run(() => vm.Auth.SetPin(vm.User, value)); pin.Password = "";'),
  ('await Task.Run(() => vm.Pos.Configure(vm.User, name.Text, tax.Text, address.Text, condition.Text));', 'var businessName = name.Text; var taxId = tax.Text; var location = address.Text; var taxCondition = condition.Text; await Task.Run(() => vm.Pos.Configure(vm.User, businessName, taxId, location, taxCondition));'),
  ('await Task.Run(() => vm.Auth.AddUser(vm.User, username.Text, name.Text, selectedRole, password.Password)); password.Password = "";', 'var login = username.Text; var displayName = name.Text; var secret = password.Password; await Task.Run(() => vm.Auth.AddUser(vm.User, login, displayName, selectedRole, secret)); password.Password = "";'),
  ('authorized = await Task.Run(() => vm.Auth.Unlock(actor, pin.Password));', 'var secret = pin.Password; authorized = await Task.Run(() => vm.Auth.Unlock(actor, secret));'),
 ],
 'src/CajaClara.Windows/MainViewModel.cs': [
  ('var quantity = (current?.QuantityMilli ?? 0) + 1000;', 'var step = product.Unit == "un" ? 1000 : Math.Min(1000, product.StockMilli);\n        if (step <= 0) throw new BusinessException("Producto sin stock.");\n        var quantity = (current?.QuantityMilli ?? 0) + step;'),
  ('Cart.Add(new CartItem(product, 1000))', 'Cart.Add(new CartItem(product, step))'),
 ],
}
changed = 0
for relative, replacements in patches.items():
    path = root / relative
    content = path.read_text(encoding='utf-8')
    original = content
    for before, after in replacements:
        if before in content:
            assert content.count(before) == 1, (relative, before)
            content = content.replace(before, after)
        elif after not in content:
            raise RuntimeError(f'Patch precondition failed: {relative}: {before[:90]}')
    if content != original:
        path.write_text(content, encoding='utf-8')
        changed += 1
print(f'Hardened {changed} source files. UI values captured before worker threads.')
