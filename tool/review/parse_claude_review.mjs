// Normalize Claude's CLI envelope into the same findings schema as Codex.
// No package dependency: validate the subset used by review-schema.json.
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';

function validate(value, schema, path = '$') {
  const types = Array.isArray(schema.type) ? schema.type : [schema.type];
  const matches = (type) => {
    switch (type) {
      case 'null': return value === null;
      case 'object': return value !== null && typeof value === 'object' && !Array.isArray(value);
      case 'array': return Array.isArray(value);
      case 'integer': return Number.isInteger(value);
      case 'number': return typeof value === 'number' && Number.isFinite(value);
      case 'string': return typeof value === 'string';
      default: throw new Error(`Unsupported schema type: ${type}`);
    }
  };
  assert(types.some(matches), `${path}: invalid type`);
  if (schema.enum) assert(schema.enum.includes(value), `${path}: invalid enum value`);
  if (typeof value === 'number') {
    if (schema.minimum !== undefined) assert(value >= schema.minimum, `${path}: below minimum`);
    if (schema.maximum !== undefined) assert(value <= schema.maximum, `${path}: above maximum`);
  }
  if (Array.isArray(value)) {
    value.forEach((item, index) => validate(item, schema.items, `${path}[${index}]`));
  } else if (value !== null && typeof value === 'object') {
    for (const key of schema.required ?? []) assert(Object.hasOwn(value, key), `${path}.${key}: missing`);
    for (const key of Object.keys(value)) {
      const property = schema.properties?.[key];
      if (!property) assert(schema.additionalProperties !== false, `${path}.${key}: unexpected`);
      else validate(value[key], property, `${path}.${key}`);
    }
  }
}

try {
  const [responsePath, schemaPath, targetPath, structured] = process.argv.slice(2);
  const response = JSON.parse(readFileSync(responsePath, 'utf8'));
  assert(response.type === 'result' && response.subtype === 'success' && response.is_error === false,
    'Claude did not return a successful result');
  const review = response.structured_output;
  validate(review, JSON.parse(readFileSync(schemaPath, 'utf8')));
  assert(review.summary.trim(), 'Review summary is empty');
  for (const finding of review.findings) {
    assert(finding.title.trim() && finding.body.trim(), 'Finding has no explanation');
    const location = finding.code_location;
    assert(location && location.filepath.trim(), 'Finding has no file evidence');
    assert(location.line_range.end >= location.line_range.start, 'Finding has a reversed line range');
  }
  assert(review.verdict === (review.findings.some((finding) => finding.priority <= 1)
    ? 'request_changes' : 'approve'), 'Verdict contradicts findings');
  const text = [review.verdict, review.summary, ...review.findings.map((finding) => {
    const location = finding.code_location;
    return `\n[P${finding.priority}] ${finding.title}\n${location.filepath}:${location.line_range.start}-${location.line_range.end}\n${finding.body}`;
  })].join('\n');
  // Write only after validation; an error envelope must never become a verdict.
  writeFileSync(targetPath, structured === 'true' ? `${JSON.stringify(review, null, 2)}\n` : `${text}\n`);
} catch (error) {
  process.stderr.write(`Invalid Claude review: ${error.message}\n`);
  process.exitCode = 1;
}
