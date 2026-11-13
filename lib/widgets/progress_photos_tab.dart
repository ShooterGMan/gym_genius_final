import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/tracker_provider.dart';
import '../services/photo_storage.dart';
import '../theme/app_theme.dart';

String _fmtDate(DateTime d) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// Progress photos: capture, browse, compare and delete.
class ProgressPhotosTab extends ConsumerWidget {
  const ProgressPhotosTab({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.photo_camera, color: AppColors.accent),
            title: const Text('Take photo', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppColors.accent),
            title: const Text('Choose from library',
                style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final name = await PhotoStorage.pickAndStore(source);
      if (name == null) return;
      await ref.read(trackerProvider.notifier).addProgressPhoto(name);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(source == ImageSource.camera
              ? 'Could not open the camera. Check camera permission in Settings.'
              : 'Could not open your photos. Check photo permission in Settings.'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = [...ref.watch(trackerProvider).photos]
      ..sort((a, b) => b.date.compareTo(a.date));
    final dirAsync = ref.watch(photoDirProvider);

    return dirAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent)),
      error: (_, __) => const Center(
          child: Text('Photos unavailable',
              style: TextStyle(color: Colors.white54))),
      data: (dir) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _add(context, ref),
                icon: const Icon(Icons.add_a_photo, color: Colors.black),
                label: const Text('ADD PHOTO',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
            if (photos.length >= 2) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.accent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _CompareScreen(
                      dir: dir,
                      before: photos.last,
                      after: photos.first,
                      all: photos,
                    ),
                  )),
                  icon: const Icon(Icons.compare, color: AppColors.accent),
                  label: const Text('COMPARE',
                      style: TextStyle(
                          color: AppColors.accent, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          const Text(
            'Photos stay on this phone and are not included in backups.',
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
          const SizedBox(height: 16),
          if (photos.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(children: [
                Icon(Icons.photo_camera_outlined,
                    color: Colors.white24, size: 48),
                SizedBox(height: 12),
                Text('No progress photos yet',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text(
                  'Same spot, same light, every 2–4 weeks. The scale lies; photos don’t.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ]),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: photos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemBuilder: (context, i) {
                final p = photos[i];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        _PhotoViewer(dir: dir, photos: photos, initial: i),
                  )),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(fit: StackFit.expand, children: [
                      _PhotoImage(path: PhotoStorage.resolve(dir, p.imagePath)),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 6),
                          color: Colors.black54,
                          child: Text(_fmtDate(p.date),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10)),
                        ),
                      ),
                    ]),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PhotoImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  const _PhotoImage({required this.path, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: fit,
      cacheWidth: fit == BoxFit.cover ? 400 : null,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.surface,
        child: const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white24)),
      ),
    );
  }
}

class _PhotoViewer extends ConsumerStatefulWidget {
  final String dir;
  final List<ProgressPhoto> photos;
  final int initial;
  const _PhotoViewer(
      {required this.dir, required this.photos, required this.initial});

  @override
  ConsumerState<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<_PhotoViewer> {
  late final PageController _ctrl = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final photo = widget.photos[_index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete photo?', style: TextStyle(color: Colors.white)),
        content: const Text('This removes it from your phone permanently.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(trackerProvider.notifier).deleteProgressPhoto(photo.id);
    await PhotoStorage.deleteFile(photo.imagePath);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_fmtDate(photo.date), style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: _PhotoImage(
              path: PhotoStorage.resolve(widget.dir, widget.photos[i].imagePath),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompareScreen extends StatefulWidget {
  final String dir;
  final ProgressPhoto before;
  final ProgressPhoto after;
  final List<ProgressPhoto> all; // newest first

  const _CompareScreen({
    required this.dir,
    required this.before,
    required this.after,
    required this.all,
  });

  @override
  State<_CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<_CompareScreen> {
  late ProgressPhoto _before = widget.before;
  late ProgressPhoto _after = widget.after;

  Future<void> _choose(bool isBefore) async {
    final picked = await showModalBottomSheet<ProgressPhoto>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in widget.all)
              ListTile(
                leading: SizedBox(
                  width: 40,
                  height: 52,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _PhotoImage(
                        path: PhotoStorage.resolve(widget.dir, p.imagePath)),
                  ),
                ),
                title: Text(_fmtDate(p.date),
                    style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, p),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isBefore) {
        _before = picked;
      } else {
        _after = picked;
      }
    });
  }

  Widget _side(ProgressPhoto p, String label, bool isBefore) => Expanded(
        child: GestureDetector(
          onTap: () => _choose(isBefore),
          child: Column(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _PhotoImage(
                    path: PhotoStorage.resolve(widget.dir, p.imagePath)),
              ),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            Text(_fmtDate(p.date),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const Text('tap to change',
                style: TextStyle(color: Colors.white24, fontSize: 10)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final days = _after.date.difference(_before.date).inDays.abs();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        title: Text('$days day${days == 1 ? '' : 's'} of progress',
            style: const TextStyle(fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          _side(_before, 'BEFORE', true),
          const SizedBox(width: 12),
          _side(_after, 'AFTER', false),
        ]),
      ),
    );
  }
}
