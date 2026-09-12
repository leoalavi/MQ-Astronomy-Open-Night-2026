// Pure validation shared by the iframe and executable regression tests.
(function (root) {
  'use strict';
  function issue(p) {
    if (!p || typeof p !== 'object') return 'missing_point';
    if ('latitude' in p || 'longitude' in p) return 'wrong_schema_latitude_longitude';
    if (!Number.isFinite(p.lat) || !Number.isFinite(p.lng)) return 'non_finite_or_missing';
    if (Math.abs(p.lat) > 90 && Math.abs(p.lat) <= 180 && Math.abs(p.lng) <= 90) return 'possibly_swapped';
    if (Math.abs(p.lat) > 90 || Math.abs(p.lng) > 180) return 'out_of_range';
    if (p.lat === 0 && p.lng === 0) return 'zero_zero';
    return null;
  }
  function span(points) {
    if (!points.length) return null;
    var lats = points.map(p => p.lat), lngs = points.map(p => p.lng);
    var minLat = Math.min(...lats), maxLat = Math.max(...lats);
    var minLng = Math.min(...lngs), maxLng = Math.max(...lngs);
    return {minLat, maxLat, minLng, maxLng, latSpan: maxLat-minLat, lngSpan: maxLng-minLng};
  }
  function distance(a, b) {
    var rad = Math.PI / 180;
    var h = Math.sin((b.lat-a.lat)*rad/2)**2 +
      Math.cos(a.lat*rad)*Math.cos(b.lat*rad)*Math.sin((b.lng-a.lng)*rad/2)**2;
    return 6371000 * 2 * Math.asin(Math.sqrt(Math.min(1, h)));
  }
  function prepare(origin, destination, route, report) {
    report = report || function () {};
    var endpoints = [origin, destination].filter(function (p, i) {
      var reason = issue(p);
      if (reason) report('INVALID_ENDPOINT index=' + i + ' reason=' + reason);
      return !reason;
    });
    var rejected = false;
    var points = (Array.isArray(route) ? route : []).filter(function (p, i) {
      var reason = issue(p);
      if (reason) { rejected = true; report('INVALID_ROUTE_POINT index=' + i + ' reason=' + reason); }
      return !reason;
    });
    if (!Array.isArray(route)) rejected = true;
    // Walking-route envelope: allow a 1 km detour or 3x endpoint separation.
    // This is generic, based on metres and supplied endpoints, not Sydney.
    var envelope = endpoints.length === 2 ? Math.max(1000, 3 * distance(...endpoints)) : 0;
    var outside = points.some(p => !endpoints.some(e => distance(e, p) <= envelope));
    if (outside || rejected || endpoints.length !== 2) {
      report('INVALID_ROUTE_BOUNDS');
      // Drop the entire suspect path; filtering a middle point could fabricate
      // a straight segment between disconnected pieces of a walking route.
      points = [];
    }
    if (!points.length) report('NO_VALID_ROUTE_GEOMETRY endpoints_only');
    return {points, endpoints, boundsPoints: endpoints.concat(points), bounds: span(endpoints.concat(points))};
  }
  root.AonRouteGeometry = {issue, span, prepare};
})(typeof globalThis !== 'undefined' ? globalThis : window);
