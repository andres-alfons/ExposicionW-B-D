import 'package:flutter/material.dart';

class NetworkComparison extends StatelessWidget {
  const NetworkComparison({super.key});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Datos móviles y Wi-Fi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Compara la infraestructura, no velocidades garantizadas. Desliza la tabla en pantallas pequeñas.',
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Característica')),
                DataColumn(label: Text('Datos móviles')),
                DataColumn(label: Text('Wi-Fi')),
              ],
              rows: const [
                DataRow(
                  cells: [
                    DataCell(Text('Infraestructura')),
                    DataCell(Text('Antenas y red celular')),
                    DataCell(Text('Punto de acceso y router')),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text('Alcance aproximado')),
                    DataCell(Text('Áreas de cobertura del operador')),
                    DataCell(Text('Habitualmente decenas de metros; variable')),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text('Operador')),
                    DataCell(Text('Requiere servicio celular')),
                    DataCell(Text('Red local sin operador celular')),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text('Acceso a Internet')),
                    DataCell(Text('Mediante el operador; no garantizado')),
                    DataCell(Text('Mediante proveedor o enlace compartido')),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text('Movilidad')),
                    DataCell(Text('Entre celdas, según cobertura')),
                    DataCell(Text('Dentro del alcance de la red')),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text('Plan de datos')),
                    DataCell(Text('Puede consumir la cuota contratada')),
                    DataCell(
                      Text('Puede consumir datos si usa un hotspot celular'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'La prueba HTTPS usa la ruta seleccionada por el sistema, que puede incluir VPN o un enlace celular compartido.',
          ),
        ],
      ),
    ),
  );
}
