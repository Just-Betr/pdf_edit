import argparse
import json
from collections import defaultdict
from pathlib import Path
import PyPDF2

# Just know I came up with these for the example.
# Make necessary changes as needed.
FIELD_TYPE_MAP = {
    'Tx': 'text',
    'Sig': 'signature',
    'Btn': 'check',
    'Ch': 'choice',
    'Rd': 'radio',
}

def _as_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None

def _normalise_name(value):
    if value is None:
        return None
    text = str(value)
    return text[1:] if text.startswith('/') else text

def _format_number(value):
    if value is None:
        return None
    return round(float(value), 3)

def _resolve_rect(rect):
    if not rect or len(rect) != 4:
        return {
            'top_left': {'x': None, 'y': None},
            'top_right': {'x': None, 'y': None},
            'bottom_left': {'x': None, 'y': None},
            'bottom_right': {'x': None, 'y': None},
            'width': None,
            'height': None,
        }

    left = _as_float(rect[0])
    bottom = _as_float(rect[1])
    right = _as_float(rect[2])
    top = _as_float(rect[3])

    top_left = {'x': left, 'y': top}
    top_right = {'x': right, 'y': top}
    bottom_left = {'x': left, 'y': bottom}
    bottom_right = {'x': right, 'y': bottom}

    width = right - left if right is not None and left is not None else None
    height = top - bottom if top is not None and bottom is not None else None

    return {
        'top_left': top_left,
        'top_right': top_right,
        'bottom_left': bottom_left,
        'bottom_right': bottom_right,
        'width': width,
        'height': height,
    }

def _round_box(box):
    if not box:
        return None
    return [_format_number(value) for value in box]

def _round_point(point):
    if not point:
        return None
    return {key: _format_number(value) for key, value in point.items()}

def _round_size(size):
    if not size:
        return None
    return {key: _format_number(value) for key, value in size.items()}

def _round_box_dict(box):
    if not box:
        return None
    return {
        key: (
            {'x': _format_number(value['x']), 'y': _format_number(value['y'])}
            if isinstance(value, dict)
            else _format_number(value)
        )
        for key, value in box.items()
    }

def get_form_field_positions(pdf_path):
    """Return metadata about all form fields in the provided PDF."""
    try:
        with open(pdf_path, 'rb') as file:
            reader = PyPDF2.PdfReader(file)

            raw_fields = reader.get_fields() or {}
            field_definitions = {
                _normalise_name(name): data for name, data in raw_fields.items() if _normalise_name(name)
            }

            if not reader.pages:
                print('The PDF contains no pages to inspect.')
                return []

            widgets_by_field = defaultdict(list)
            field_types = {}

            page_metrics = {}

            for page_index, page in enumerate(reader.pages, start=1):
                mediabox = page.mediabox
                width = float(mediabox.right) - float(mediabox.left)
                height = float(mediabox.top) - float(mediabox.bottom)
                page_metrics[page_index] = {'width': width, 'height': height}

                annotations = page.get('/Annots', [])
                if not annotations:
                    continue

                for annotation_ref in annotations:
                    annotation = annotation_ref.get_object()
                    parent_ref = annotation.get('/Parent')
                    parent = parent_ref.get_object() if parent_ref else None

                    name_obj = annotation.get('/T') or (parent.get('/T') if parent else None)
                    field_name = _normalise_name(name_obj)
                    if field_name is None:
                        continue

                    rect = annotation.get('/Rect') or (parent.get('/Rect') if parent else None)
                    rect_info = _resolve_rect(rect)
                    bottom_left = rect_info['bottom_left']
                    top_left = rect_info['top_left']
                    width = rect_info['width']
                    height = rect_info['height']
                    page_height = page_metrics[page_index]['height']

                    field_types[field_name] = _normalise_name(
                        (parent or annotation).get('/FT') or field_definitions.get(field_name, {}).get('/FT'),
                    )

                    widgets_by_field[field_name].append(
                        {
                            'page': page_index,
                            'boundingBox': rect_info if rect else None,
                            'position': bottom_left if rect else None,
                            'size': {'width': width, 'height': height} if rect else None,
                            'flutterConfig': (
                                {
                                    'pageIndex': page_index - 1,
                                    'x': _format_number(bottom_left['x']) if bottom_left else None,
                                    'y': (
                                        _format_number(page_height - top_left['y'])
                                        if (top_left and top_left['y'] is not None and page_height is not None)
                                        else None
                                    ),
                                    'width': _format_number(width),
                                    'height': _format_number(height),
                                    'positionUnit': 'points',
                                    'sizeUnit': 'points',
                                }
                                if rect and page_height is not None
                                else None
                            ),
                        },
                    )

            print('Found the following form fields:')
            print('-' * 40)

            results = []
            all_field_names = set(field_definitions.keys()) | set(widgets_by_field.keys())

            for field_name in sorted(all_field_names):
                widgets = widgets_by_field.get(field_name, [])
                field_type = field_types.get(field_name)
                primary = widgets[0] if widgets else {
                    'page': None,
                    'boundingBox': None,
                    'position': None,
                    'size': None,
                }

                mapped_type = FIELD_TYPE_MAP.get(field_type, field_type)
                print(f'Field Name: {field_name}')
                print(f"Page: {primary['page'] if primary['page'] is not None else 'Unknown'}")
                if primary['boundingBox']:
                    width = primary['size']['width'] if primary['size'] else None
                    height = primary['size']['height'] if primary['size'] else None
                    bottom_left = primary['boundingBox']['bottom_left']
                    top_left = primary['boundingBox']['top_left']
                    template_y = None
                    if top_left and top_left['y'] is not None and primary['page'] in page_metrics:
                        template_y = page_metrics[primary['page']]['height'] - top_left['y']
                    rounded_box = _round_box_dict(primary['boundingBox'])
                    rounded_position = _round_point(bottom_left) if bottom_left else None
                    rounded_size = _round_size({'width': width, 'height': height})
                    print(f'Bounding Box Corners: {rounded_box}')
                    if rounded_position:
                        print(f'Position (bottom-left): ({rounded_position["x"]}, {rounded_position["y"]}) pts')
                    print(
                        f'Dimensions (width, height): '
                        f'({rounded_size["width"]}, {rounded_size["height"]}) pts'
                    )
                else:
                    print('Bounding Box: Not available')
                if field_type:
                    print(f'Field Type: {mapped_type}')
                print('-' * 40)

                results.append(
                    {
                        'name': field_name,
                        'field_type': mapped_type,
                        'page': primary['page'],
                        'page_size': _round_size(page_metrics.get(primary['page'])),
                        'bounding_box': _round_box_dict(primary['boundingBox']),
                        'position': _round_point(primary['position']),
                        'size': _round_size(primary['size']),
                    },
                )

            return results

    except FileNotFoundError:
        print(f"Error: The file at '{pdf_path}' was not found.")
    except Exception as error:
        print(f'An unexpected error occurred: {error}')

    return []

def main():
    parser = argparse.ArgumentParser(description='Inspect PDF form field geometry.')
    parser.add_argument('pdf_path', help='Path to the PDF file to inspect.')
    parser.add_argument(
        '-o',
        '--output',
        help='Optional JSON file path. Defaults to <pdf_name>.form_fields.json next to the PDF.',
    )
    args = parser.parse_args()

    pdf_path = Path(args.pdf_path)
    fields = get_form_field_positions(pdf_path)

    output_path = Path(args.output) if args.output else pdf_path.with_suffix('.form_fields.json')
    try:
        with output_path.open('w', encoding='utf-8') as handle:
            json.dump(fields, handle, indent=2)
    except Exception as error:
        print(f'Failed to write JSON output: {error}')
        return

    print(f'\nSaved {len(fields)} field definitions to {output_path.resolve()}')

if __name__ == '__main__':
    main()