/// Contratos de formulario; las reglas y los permisos definitivos viven en la API.
enum FieldKind {
  text,
  multiline,
  number,
  date,
  dateTime,
  toggle,
  choice,
  reference,
}

class ModuleField {
  const ModuleField(
    this.key,
    this.label, {
    this.kind = FieldKind.text,
    this.required = false,
    this.choices = const {},
    this.reference,
    this.initial,
  });
  final String key, label;
  final FieldKind kind;
  final bool required;
  final Map<String, String> choices;
  final String? reference;
  final Object? initial;
}

class MobileModule {
  const MobileModule(
    this.key,
    this.title,
    this.endpoint, {
    this.description = '',
    this.permission,
    this.fields = const [],
    this.readOnly = false,
    this.identity = 'id',
    this.editSuffix = '/',
    this.canCreate = true,
  });
  final String key, title, endpoint, description, identity, editSuffix;
  final String? permission;
  final bool readOnly, canCreate;
  final List<ModuleField> fields;
  String get route => '/gestion/$key';
}

const activeStates = {'ACTIVE': 'Activo', 'INACTIVE': 'Inactivo'};
const personFields = [
  ModuleField('first_name', 'Nombres', required: true),
  ModuleField('last_name', 'Apellidos', required: true),
  ModuleField('document_number', 'Documento'),
  ModuleField('phone', 'Teléfono'),
  ModuleField('contact_email', 'Correo de contacto'),
];
const mobileModules = <String, MobileModule>{
  'condominium': MobileModule(
    'condominium',
    'Mi condominio',
    '/community/condominium/',
    permission: 'manage_settings',
    canCreate: false,
    description: 'Datos y normas de tu condominio actual.',
    fields: [
      ModuleField('name', 'Nombre', required: true),
      ModuleField('legal_name', 'Razón social'),
      ModuleField('address', 'Dirección', kind: FieldKind.multiline),
      ModuleField('phone', 'Teléfono'),
      ModuleField('email', 'Correo de contacto'),
      ModuleField('timezone', 'Zona horaria', required: true),
      ModuleField(
        'rules_summary',
        'Normas de convivencia',
        kind: FieldKind.multiline,
      ),
    ],
  ),
  'staff': MobileModule(
    'staff',
    'Personal del condominio',
    '/staff/',
    permission: 'manage_staff',
    description: 'Registra al equipo y organiza sus áreas de trabajo.',
    fields: [
      ...personFields,
      ModuleField(
        'staff_type',
        'Área',
        required: true,
        kind: FieldKind.choice,
        choices: {
          'ADMINISTRATION': 'Administración',
          'SECURITY': 'Seguridad',
          'MAINTENANCE': 'Mantenimiento',
          'CLEANING': 'Limpieza',
          'OTHER': 'Otro',
        },
      ),
      ModuleField('hire_date', 'Fecha de incorporación', kind: FieldKind.date),
      ModuleField('end_date', 'Último día de trabajo', kind: FieldKind.date),
      ModuleField(
        'status',
        'Estado',
        kind: FieldKind.choice,
        choices: {...activeStates, 'SUSPENDED': 'Suspendido'},
        initial: 'ACTIVE',
      ),
      ModuleField('notes', 'Notas', kind: FieldKind.multiline),
    ],
  ),
  'residents': MobileModule(
    'residents',
    'Residentes y copropietarios',
    '/residents/',
    permission: 'manage_residents',
    description: 'Mantén los datos personales y el estado de los residentes.',
    fields: [
      ...personFields,
      ModuleField(
        'status',
        'Estado',
        kind: FieldKind.choice,
        choices: {...activeStates, 'BLOCKED': 'Bloqueado'},
        initial: 'ACTIVE',
      ),
      ModuleField('notes', 'Notas', kind: FieldKind.multiline),
    ],
  ),
  'sectors': MobileModule(
    'sectors',
    'Sectores del condominio',
    '/sectors/',
    permission: 'manage_units',
    description: 'Organiza bloques, torres, pisos y zonas.',
    fields: [
      ModuleField('code', 'Código', required: true),
      ModuleField('name', 'Nombre', required: true),
      ModuleField(
        'sector_type',
        'Tipo',
        kind: FieldKind.choice,
        choices: {
          'SECTOR': 'Sector',
          'BLOCK': 'Bloque',
          'TOWER': 'Torre',
          'FLOOR': 'Piso',
          'ZONE': 'Zona',
          'OTHER': 'Otro',
        },
        initial: 'SECTOR',
      ),
      ModuleField(
        'parent',
        'Sector superior',
        kind: FieldKind.reference,
        reference: 'sectors',
      ),
      ModuleField('description', 'Descripción', kind: FieldKind.multiline),
      ModuleField('is_active', 'Activo', kind: FieldKind.toggle, initial: true),
    ],
  ),
  'units': MobileModule(
    'units',
    'Unidades habitacionales',
    '/units/',
    permission: 'manage_units',
    description: 'Casas, departamentos y espacios del condominio.',
    fields: [
      ModuleField('code', 'Código de unidad', required: true),
      ModuleField(
        'sector',
        'Sector',
        required: true,
        kind: FieldKind.reference,
        reference: 'sectors',
      ),
      ModuleField(
        'unit_type',
        'Tipo',
        kind: FieldKind.choice,
        choices: {
          'HOUSE': 'Casa',
          'APARTMENT': 'Departamento',
          'OFFICE': 'Oficina',
          'STORE': 'Local',
          'OTHER': 'Otro',
        },
        initial: 'APARTMENT',
      ),
      ModuleField('floor_label', 'Piso'),
      ModuleField('description', 'Descripción', kind: FieldKind.multiline),
      ModuleField(
        'status',
        'Estado',
        kind: FieldKind.choice,
        choices: {...activeStates, 'MAINTENANCE': 'En mantenimiento'},
        initial: 'ACTIVE',
      ),
    ],
  ),
  'resident-units': MobileModule(
    'resident-units',
    'Asignación de unidades',
    '/resident-units/',
    permission: 'manage_residents',
    description: 'Vincula residentes y unidades conservando su historial.',
    fields: [
      ModuleField(
        'resident',
        'Residente',
        required: true,
        kind: FieldKind.reference,
        reference: 'residents',
      ),
      ModuleField(
        'unit',
        'Unidad',
        required: true,
        kind: FieldKind.reference,
        reference: 'units',
      ),
      ModuleField(
        'relation_type',
        'Relación',
        kind: FieldKind.choice,
        required: true,
        choices: {
          'OWNER': 'Propietario',
          'TENANT': 'Inquilino',
          'FAMILY': 'Familiar',
          'AUTHORIZED': 'Autorizado',
          'OTHER': 'Otro',
        },
      ),
      ModuleField(
        'is_primary',
        'Unidad principal',
        kind: FieldKind.toggle,
        initial: false,
      ),
      ModuleField(
        'start_date',
        'Fecha de inicio',
        required: true,
        kind: FieldKind.date,
      ),
      ModuleField('end_date', 'Fecha de finalización', kind: FieldKind.date),
    ],
  ),
  'roles': MobileModule(
    'roles',
    'Roles y permisos',
    '/roles/',
    permission: 'manage_roles',
    identity: 'slug',
    editSuffix: '/permissions/',
    canCreate: false,
    description:
        'Consulta los roles y edita sus permisos. Las reglas críticas se validan en el servidor.',
  ),
  'audit': MobileModule(
    'audit',
    'Auditoría y bitácora',
    '/community/audit/',
    permission: 'manage_roles',
    readOnly: true,
    description:
        'Consulta las operaciones registradas. La bitácora no se puede modificar ni eliminar.',
  ),
  'areas': MobileModule(
    'areas',
    'Áreas comunes',
    '/community/areas/',
    permission: 'manage_reservations',
    description:
        'Consulta los espacios disponibles y administra su disponibilidad.',
    fields: [
      ModuleField('name', 'Nombre', required: true),
      ModuleField('description', 'Descripción', kind: FieldKind.multiline),
      ModuleField(
        'sector',
        'Sector',
        kind: FieldKind.reference,
        reference: 'sectors',
      ),
      ModuleField('capacity', 'Capacidad', kind: FieldKind.number),
      ModuleField(
        'requires_approval',
        'Requiere aprobación',
        kind: FieldKind.toggle,
        initial: false,
      ),
      ModuleField(
        'status',
        'Disponibilidad',
        kind: FieldKind.choice,
        choices: {
          'AVAILABLE': 'Disponible',
          'UNAVAILABLE': 'No disponible',
          'MAINTENANCE': 'En mantenimiento',
          'INACTIVE': 'Inactiva',
        },
        initial: 'AVAILABLE',
      ),
    ],
  ),
  'reservations': MobileModule(
    'reservations',
    'Reservas de áreas',
    '/community/reservations/',
    permission: 'manage_reservations',
    description:
        'Reserva un espacio, revisa horarios y consulta el estado de tu solicitud.',
    fields: [
      ModuleField(
        'common_area',
        'Área común',
        required: true,
        kind: FieldKind.reference,
        reference: 'areas',
      ),
      ModuleField(
        'resident',
        'Residente',
        required: true,
        kind: FieldKind.reference,
        reference: 'residents',
      ),
      ModuleField(
        'start_at',
        'Inicio de la reserva',
        required: true,
        kind: FieldKind.dateTime,
      ),
      ModuleField(
        'end_at',
        'Fin de la reserva',
        required: true,
        kind: FieldKind.dateTime,
      ),
      ModuleField('purpose', 'Motivo'),
      ModuleField(
        'status',
        'Estado',
        kind: FieldKind.choice,
        choices: {
          'PENDING': 'Pendiente',
          'APPROVED': 'Aprobada',
          'REJECTED': 'Rechazada',
          'CANCELLED': 'Cancelada',
          'COMPLETED': 'Completada',
        },
        initial: 'PENDING',
      ),
    ],
  ),
  'announcements': MobileModule(
    'announcements',
    'Comunicados y avisos',
    '/community/announcements/',
    permission: 'manage_announcements',
    description: 'Mantente al día con los avisos de tu comunidad.',
    fields: [
      ModuleField('title', 'Título', required: true),
      ModuleField(
        'body',
        'Comunicado',
        required: true,
        kind: FieldKind.multiline,
      ),
      ModuleField(
        'audience',
        'Destinatarios',
        kind: FieldKind.choice,
        choices: {
          'ALL': 'Todos',
          'RESIDENTS': 'Residentes',
          'STAFF': 'Personal',
          'SECURITY': 'Seguridad',
          'MAINTENANCE': 'Mantenimiento',
          'DIRECTIVE': 'Directiva',
        },
        initial: 'ALL',
      ),
      ModuleField(
        'priority',
        'Prioridad',
        kind: FieldKind.choice,
        choices: {
          'LOW': 'Baja',
          'NORMAL': 'Normal',
          'HIGH': 'Alta',
          'URGENT': 'Urgente',
        },
        initial: 'NORMAL',
      ),
      ModuleField(
        'status',
        'Publicación',
        kind: FieldKind.choice,
        choices: {
          'DRAFT': 'Borrador',
          'PUBLISHED': 'Publicado',
          'ARCHIVED': 'Archivado',
        },
        initial: 'DRAFT',
      ),
      ModuleField('published_at', 'Publicar desde', kind: FieldKind.dateTime),
      ModuleField('expires_at', 'Vencimiento', kind: FieldKind.dateTime),
    ],
  ),
  'assemblies': MobileModule(
    'assemblies',
    'Asambleas',
    '/community/assemblies/',
    permission: 'manage_settings',
    description: 'Consulta las convocatorias y sus actas.',
    fields: [
      ModuleField('title', 'Título', required: true),
      ModuleField('description', 'Convocatoria', kind: FieldKind.multiline),
      ModuleField(
        'scheduled_at',
        'Fecha y hora',
        required: true,
        kind: FieldKind.dateTime,
      ),
      ModuleField('location', 'Lugar'),
      ModuleField(
        'status',
        'Estado',
        kind: FieldKind.choice,
        choices: {
          'SCHEDULED': 'Programada',
          'IN_PROGRESS': 'En progreso',
          'FINISHED': 'Finalizada',
          'CANCELLED': 'Cancelada',
        },
        initial: 'SCHEDULED',
      ),
      ModuleField(
        'minutes_text',
        'Acta de la asamblea',
        kind: FieldKind.multiline,
      ),
    ],
  ),
  'agreements': MobileModule(
    'agreements',
    'Acuerdos',
    '/community/agreements/',
    permission: 'manage_settings',
    description: 'Da seguimiento a los compromisos de cada asamblea.',
    fields: [
      ModuleField(
        'assembly',
        'Asamblea',
        required: true,
        kind: FieldKind.reference,
        reference: 'assemblies',
      ),
      ModuleField('title', 'Título', required: true),
      ModuleField('description', 'Detalle', kind: FieldKind.multiline),
      ModuleField('due_at', 'Fecha objetivo', kind: FieldKind.dateTime),
      ModuleField(
        'status',
        'Estado',
        kind: FieldKind.choice,
        choices: {
          'PENDING': 'Pendiente',
          'IN_PROGRESS': 'En progreso',
          'COMPLETED': 'Completado',
          'OVERDUE': 'Vencido',
          'CANCELLED': 'Cancelado',
        },
        initial: 'PENDING',
      ),
      ModuleField(
        'estimated_budget',
        'Presupuesto estimado (Bs)',
        kind: FieldKind.number,
      ),
      ModuleField('actual_cost', 'Costo real (Bs)', kind: FieldKind.number),
    ],
  ),
};
