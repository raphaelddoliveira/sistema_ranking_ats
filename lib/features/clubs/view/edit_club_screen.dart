import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../services/storage_service.dart';
import '../data/club_repository.dart';
import '../viewmodel/club_providers.dart';

class EditClubScreen extends ConsumerStatefulWidget {
  final String clubId;

  const EditClubScreen({super.key, required this.clubId});

  @override
  ConsumerState<EditClubScreen> createState() => _EditClubScreenState();
}

class _EditClubScreenState extends ConsumerState<EditClubScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic info
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Contacts
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();

  // Address
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _complementController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  String? _selectedState;

  bool _isSaving = false;
  bool _isUploadingLogo = false;
  bool _isUploadingCover = false;

  @override
  void initState() {
    super.initState();
    final club = ref.read(currentClubProvider).valueOrNull;
    if (club != null) {
      _nameController.text = club.name;
      _descriptionController.text = club.description ?? '';
      _phoneController.text = club.phone ?? '';
      _emailController.text = club.email ?? '';
      _websiteController.text = club.website ?? '';
      _streetController.text = club.addressStreet ?? '';
      _numberController.text = club.addressNumber ?? '';
      _complementController.text = club.addressComplement ?? '';
      _neighborhoodController.text = club.addressNeighborhood ?? '';
      _cityController.text = club.addressCity ?? '';
      _zipController.text = club.addressZip ?? '';
      _selectedState = club.addressState;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  // ─── Image Upload ──────────────────────────────────────────

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;

    XFile fileToUpload = picked;
    if (!kIsWeb) {
      try {
        final cropped = await ImageCropper().cropImage(
          sourcePath: picked.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Recortar logo',
              toolbarColor: AppColors.primary,
              toolbarWidgetColor: Colors.white,
              lockAspectRatio: true,
              cropStyle: CropStyle.circle,
            ),
            IOSUiSettings(
              title: 'Recortar logo',
              aspectRatioLockEnabled: true,
              cropStyle: CropStyle.circle,
            ),
          ],
        );
        if (cropped == null) return;
        fileToUpload = XFile(cropped.path);
      } catch (_) {}
    }

    setState(() => _isUploadingLogo = true);
    try {
      final url = await ref
          .read(storageServiceProvider)
          .uploadClubLogo(widget.clubId, fileToUpload);
      await ref
          .read(clubRepositoryProvider)
          .updateClub(widget.clubId, avatarUrl: url);
      ref.invalidate(currentClubProvider);
      if (mounted) SnackbarUtils.showSuccess(context, 'Logo atualizado!');
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, 'Erro ao enviar logo: $e');
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (picked == null) return;

    XFile fileToUpload = picked;
    if (!kIsWeb) {
      try {
        final cropped = await ImageCropper().cropImage(
          sourcePath: picked.path,
          aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Recortar capa',
              toolbarColor: AppColors.primary,
              toolbarWidgetColor: Colors.white,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Recortar capa',
              aspectRatioLockEnabled: true,
            ),
          ],
        );
        if (cropped == null) return;
        fileToUpload = XFile(cropped.path);
      } catch (_) {}
    }

    setState(() => _isUploadingCover = true);
    try {
      final url = await ref
          .read(storageServiceProvider)
          .uploadClubCover(widget.clubId, fileToUpload);
      await ref
          .read(clubRepositoryProvider)
          .updateClub(widget.clubId, coverUrl: url);
      ref.invalidate(currentClubProvider);
      if (mounted) SnackbarUtils.showSuccess(context, 'Capa atualizada!');
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Erro ao enviar capa: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  // ─── Save ──────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(clubRepositoryProvider).updateClub(
            widget.clubId,
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            website: _websiteController.text.trim().isEmpty
                ? null
                : _websiteController.text.trim(),
            addressStreet: _streetController.text.trim().isEmpty
                ? null
                : _streetController.text.trim(),
            addressNumber: _numberController.text.trim().isEmpty
                ? null
                : _numberController.text.trim(),
            addressComplement: _complementController.text.trim().isEmpty
                ? null
                : _complementController.text.trim(),
            addressNeighborhood: _neighborhoodController.text.trim().isEmpty
                ? null
                : _neighborhoodController.text.trim(),
            addressCity: _cityController.text.trim().isEmpty
                ? null
                : _cityController.text.trim(),
            addressState: _selectedState,
            addressZip: _zipController.text.trim().isEmpty
                ? null
                : _zipController.text.trim(),
          );
      ref.invalidate(currentClubProvider);
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Clube atualizado!');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Erro ao salvar: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final clubAsync = ref.watch(currentClubProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Clube')),
      body: clubAsync.when(
        data: (club) {
          if (club == null) {
            return const Center(child: Text('Clube não encontrado'));
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildImagesSection(club.avatarUrl, club.coverUrl),
                const SizedBox(height: 24),
                _buildBasicInfoSection(),
                const SizedBox(height: 24),
                _buildAddressSection(),
                const SizedBox(height: 24),
                _buildContactsSection(),
                const SizedBox(height: 32),
                _buildSaveButton(),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  // ─── Images Section ────────────────────────────────────────

  Widget _buildImagesSection(String? logoUrl, String? coverUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Imagens',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        // Cover
        GestureDetector(
          onTap: _isUploadingCover ? null : _pickCover,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              image: coverUrl != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(coverUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _isUploadingCover
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : coverUrl == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.panorama_outlined,
                              size: 40, color: AppColors.onBackgroundLight),
                          const SizedBox(height: 8),
                          Text(
                            'Toque para adicionar capa',
                            style: TextStyle(
                              color: AppColors.onBackgroundLight,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    : Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(120),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ),
          ),
        ),
        const SizedBox(height: 16),
        // Logo
        Center(
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.secondaryGradient,
                ),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.background,
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.surfaceVariant,
                    backgroundImage: logoUrl != null
                        ? CachedNetworkImageProvider(logoUrl)
                        : null,
                    child: _isUploadingLogo
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : logoUrl == null
                            ? const Icon(Icons.groups_rounded,
                                size: 36, color: AppColors.onBackgroundLight)
                            : null,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingLogo ? null : _pickLogo,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.background, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Logo do clube',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onBackgroundLight,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Basic Info Section ────────────────────────────────────

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informações básicas',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nome do clube',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Nome é obrigatório' : null,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Descrição',
            prefixIcon: Icon(Icons.description_outlined),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  // ─── Address Section ───────────────────────────────────────

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Endereço',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(
                  labelText: 'Rua',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(
                  labelText: 'Nº',
                ),
                keyboardType: TextInputType.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _complementController,
          decoration: const InputDecoration(
            labelText: 'Complemento',
            prefixIcon: Icon(Icons.apartment_outlined),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _neighborhoodController,
          decoration: const InputDecoration(
            labelText: 'Bairro',
            prefixIcon: Icon(Icons.map_outlined),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'Cidade',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'UF',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedState,
                    isDense: true,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('-'),
                      ),
                      ..._brazilianStates.map(
                        (uf) => DropdownMenuItem(
                          value: uf,
                          child: Text(uf),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedState = v),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _zipController,
          decoration: const InputDecoration(
            labelText: 'CEP',
            prefixIcon: Icon(Icons.markunread_mailbox_outlined),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
        ),
      ],
    );
  }

  // ─── Contacts Section ──────────────────────────────────────

  Widget _buildContactsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contatos',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Telefone',
            prefixIcon: Icon(Icons.phone_outlined),
            hintText: '(11) 99999-9999',
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'E-mail',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _websiteController,
          decoration: const InputDecoration(
            labelText: 'Website',
            prefixIcon: Icon(Icons.language_outlined),
            hintText: 'www.meusclub.com.br',
          ),
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  // ─── Save Button ───────────────────────────────────────────

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _save,
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check),
        label: Text(_isSaving ? 'Salvando...' : 'Salvar'),
      ),
    );
  }

  static const _brazilianStates = [
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO',
    'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI',
    'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
  ];
}
