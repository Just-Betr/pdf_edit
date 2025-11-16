## 0.4.0
* Converted signature rendering into a pluggable strategy via `SignatureRenderer` with `PaintingSignatureRenderer` as the default implementation.
* Allow `PdfDocumentBuilder` and `PdfDocument` to accept custom signature renderers while keeping the public API defaults intact.
* Documented the new strategy in the README and refreshed the associated tests.

## 0.3.2
* Had to merge the simplify API branch. Again nothing interestin but chores.

## 0.3.1
* Mandatory versioning to publish 0.3.0. This update is really nothing important.

## 0.3.0
* Simplified the PDF generation flow so `PdfDocument` resolves assets, rasterises pages, and assembles templates internally.
* Removed the public template loader API to keep the surface area focused on builder → data → generate.
* Updated documentation to reflect the streamlined workflow and added sequence diagrams for quick reference.

## 0.2.2
* Dart format every file.

## 0.2.1
* Issue with publishing fix.

## 0.2.0
* Tried to potentially move away from Printing package. However the rasterization it provides its the backbone.

## 0.1.0

* Initial release. Bare-minimum API to generate bytes and save updated PDF.