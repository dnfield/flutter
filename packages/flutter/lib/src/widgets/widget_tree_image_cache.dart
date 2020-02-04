// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/painting.dart';

import 'framework.dart';

void debugDumpWidgetImageCache() {
  if (_cache._cache.isEmpty) {
    debugPrint('No images in widget tree cache.');
    return;
  }
  debugPrint('Images in widget tree cache:');
  for (final MapEntry<Object, _CacheImage> kvp in _cache._cache.entries) {
    debugPrint('  ${kvp.key}');
    debugPrint('    ${kvp.value}');
  }
}

class _CacheImage {
  _CacheImage(this.listener) : assert(listener != null);

  final List<ImageStream> streams = <ImageStream>[];
  final ImageStreamListener listener;

  ImageStreamCompleter completer;

  void addStream(ImageStream stream) {
    assert(identical(stream.completer ?? completer, completer ?? stream.completer));
    if (stream.completer != null && completer == null) {
      setCompleter(stream.completer);
    } else if (completer != null && stream.completer == null) {
      stream.setCompleter(completer);
    } else if (completer == null && stream.completer == null) {
      stream.addListener(listener);
    }
    streams.add(stream);
  }

  void setCompleter(ImageStreamCompleter completer) {
    assert(completer != null);
    this.completer = completer;
    for (final ImageStream stream in streams) {
      stream.removeListener(listener);
      if (stream.completer == null) {
        stream.setCompleter(completer);
      }
    }
  }

  @override
  String toString() {
    final String streamLength = streams.length == 1
      ? '1 stream'
      : '${streams.length} streams';
    final String completerDescription = completer == null
      ? '<no completer>'
      : completer.toString();
    return '_CacheWidgetImage($streamLength, $completerDescription)';
  }

}

class _WidgetTreeImageCache {
  _WidgetTreeImageCache();

  final Map<Object, _CacheImage> _cache = <Object, _CacheImage>{};

  bool containsKey(Object key) => _cache[key] != null;

  void removeRef(Object key, ImageStream stream) {
    assert(key != null);
    assert(stream != null);
    assert(_cache.containsKey(key));
    // assert(_cache[key].streams.contains(stream));
    _cache[key].streams.remove(stream);
    if (_cache[key].streams.isEmpty) {
      _cache.remove(key);
    }
  }

  ImageStreamListener _createListener(Object key, ImageStream stream) {
    return ImageStreamListener(
      (ImageInfo image, bool syncCall) {
        assert(stream.completer != null);
        final _CacheImage cacheImage = _cache[key];
        assert(cacheImage != null);
        cacheImage.setCompleter(stream.completer);
      },
    );
  }

  bool add(Object key, ImageStream stream) {
    assert(key != null);
    assert(stream != null);
    bool createdCacheImage = false;
    _cache.putIfAbsent(
      key,
      () {
        createdCacheImage = true;
        return _CacheImage(_createListener(key, stream));
      },
    )..addStream(stream);
    return createdCacheImage;
  }
}

_WidgetTreeImageCache _cache = _WidgetTreeImageCache();

@optionalTypeArgs
class WidgetTreeImageProvider<T> extends ImageProvider<T> {
  WidgetTreeImageProvider({
    @required this.imageProvider,
  }) : assert(imageProvider != null);

  /// The wrapped image provider to delegate [obtainKey] and [load] to.
  final ImageProvider<T> imageProvider;

  T _obtainedKey;
  ImageStream _stream;

  /// Called when the [State] that created this provider does not want to
  /// listen to the stream anymore.
  ///
  /// When all states listening for images with the same key call this,
  /// the image is dropped from the widget tree cache.
  void removeListener(ImageStreamListener listener) {
    _stream.removeListener(listener);
    if (_obtainedKey == null) {
      return;
    }
    _cache.removeRef(_obtainedKey, _stream);
  }

  @override
  ImageStream createStream(ImageConfiguration configuration) {
    _stream ??= super.createStream(configuration);
    return _stream;
  }

  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    T key,
    ImageErrorListener handleError,
  ) {
    assert(identical(_stream, stream));
    _obtainedKey = key; //_Key(key, configuration);
    final bool added = _cache.add(_obtainedKey, stream);
    if (stream.completer != null || added) {
      imageProvider.resolveStreamForKey(configuration, stream, key, handleError);
      return;
    }
  }

  @override
  ImageStreamCompleter load(T key, DecoderCallback decode) => imageProvider.load(key, decode);

  @override
  Future<T> obtainKey(ImageConfiguration configuration) => imageProvider.obtainKey(configuration);
}
