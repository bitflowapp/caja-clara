"""Finalize the isolated branch only after all executable suites pass."""
from pathlib import Path
import json
import subprocess

root = Path(__file__).resolve().parents[1]
artifacts = root / 'artifacts'
suites = {}
for name in ('test-results.json','cloud-test-results.json','ui-test-results.json','browser-test-results.json','installer-test-results.json'):
    result = json.loads((artifacts / name).read_text(encoding='utf-8-sig'))
    if result['failed'] or result['passed'] != result['total']:
        raise RuntimeError('Release finalization refused: ' + name)
    suites[name] = {'passed': result['passed'], 'total': result['total']}
source = (artifacts / 'source-commit.txt').read_text(encoding='utf-8-sig').strip()
total = sum(s['total'] for s in suites.values())
report = f'''# Estado verificado de Caja Clara Native 0.2.0

Fuente compilada: `{source}`. Evidencia generada por Windows CI; las capturas son de pruebas aisladas.

**{total}/{total} comprobaciones ejecutadas aprobadas. Esto no significa que el alcance comercial completo esté terminado.**

| Suite | Resultado |
|---|---:|
'''
for name, suite in suites.items():
    report += f"| {name} | {suite['passed']}/{suite['total']} |\n"
report += '''
## Aceptación por capacidad

```text
CAJA_CLARA_BUILD: PASS
WINDOWS_NATIVE: PASS — ejecución y flujo de UI real
LOCAL_DATABASE: PASS
POS_FLOW: PASS
STOCK: PASS
CASH_REGISTER: PASS
PAYMENTS: PASS — efectivo y registros electrónicos manuales, pagos combinados
MERCADO_PAGO: FAIL — integración de proveedor no implementada
FISCAL_ARCA: FAIL — solo cola comercial pendiente, sin emisión WSAA/WSFE
PRINTING: NOT_VERIFIED — código nativo presente; hardware físico no probado
PDF_INVOICE: FAIL — no hay factura fiscal autorizada
PDF_INTERNAL_RECEIPT: PASS
XLSX: PASS
OFFLINE_MODE: PASS — ventas y persistencia local sin servidor
SYNC: PASS — HTTP real, no rutas simuladas
REMOTE_MOBILE: PASS — navegador móvil; no instalación iPhone físico
REMOTE_COMMANDS: PASS — precio, disponibilidad, cierre solicitado y sincronización
REMOTE_DISCOUNT_REFUND_APPROVALS: FAIL — no implementadas
BACKUPS: PASS — creación y validación de integridad
RESTORE_FULL_FLOW: NOT_VERIFIED
SECURITY_CONTROLS: PASS — permisos, aislamiento, CSRF y revocación probados
SECURITY_INDEPENDENT_REVIEW: NOT_VERIFIED
INSTALLER: PASS — instalación y desinstalación preservan datos
AUTHENTICODE_SIGNATURE: NOT_CONFIGURED
MULTI_REGISTER_CONCURRENT: NOT_SUPPORTED — una caja primaria
PRODUCTION_READINESS: NO
```

No se crearon cuentas reales con claves predeterminadas. Las cuentas QA usaron secretos aleatorios, excluidos de los artefactos. El dueño crea su cuenta al iniciar la aplicación y crea por separado su cuenta cloud mediante `--init`.

El paquete contiene app Windows, terminal, servidor, instalador por usuario y documentación. No se desplegó un dominio público ni se conectaron cuentas fiscales o financieras. ARCA y Mercado Pago requieren **implementación y homologación**, no únicamente entregar una contraseña.

Antes de uso comercial definitivo: completar las integraciones faltantes, tratamiento de notas fiscales y conciliación, firma de distribución, impresión/scanner físicos, escenarios de restauración, carga y cortes de energía, revisión de seguridad y despliegue HTTPS con backups del servidor. Leer FISCAL.md, MERCADOPAGO.md y SECURITY.md.
'''
(root / 'docs/BUILD_REPORT.md').write_text(report, encoding='utf-8')
(artifacts / 'release-status.json').write_text(json.dumps({'compiled_source_commit': source, 'total_tests': total, 'passed_tests': total, 'suites': suites, 'production_ready': False, 'fiscal_arca': 'NOT_IMPLEMENTED', 'mercado_pago': 'NOT_IMPLEMENTED'}, indent=2), encoding='utf-8')
workflow = root.parent / '.github/workflows/caja-clara-native.yml'
text = workflow.read_text(encoding='utf-8').replace('  contents: write', '  contents: read')
start = text.index('      - name: Apply verified source corrections\n')
end = text.index('      - name: Build core and execute tests\n', start)
text = text[:start] + text[end:]
start = text.index('      - name: Finalize isolated development branch\n')
end = text.index('      - name: Collect package documentation\n', start)
text = text[:start] + text[end:]
workflow.write_text(text, encoding='utf-8')
for script in (root / 'tools').glob('*.py'):
    script.unlink()
subprocess.run(['git','add','native','.github/workflows/caja-clara-native.yml'], cwd=root.parent, check=True)
subprocess.run(['git','commit','-m','Finalize verified native candidate, document scope and make CI read-only'], cwd=root.parent, check=True)
subprocess.run(['git','push','origin','HEAD:work/caja-clara-native-20260921'], cwd=root.parent, check=True)
print(f'Finalized {total} passing checks. Fiscal/payment integrations remain explicitly incomplete.')
