; Purpose: XML and HTML as expressions, and the selector language over them.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/29-markup_lib.metta; commit=WORKTREE].
!(import! &self (library lib_markup))

; An element is (element Name Attributes Children): the name a Symbol, each
; attribute an (attr Name Value) row and the children an expression of elements and
; Strings. Nothing in a document is opaque, so a program reads one by
; pattern-matching it. The attribute row is TAGGED because an untagged (id "7")
; pair is an expression whose head names the engine's identity function, and it
; would be evaluated as a call where the document is written.
!(bind! &doc (markup-parse-xml "<order id='7'><item sku='a'>apple</item><item sku='b'>pear</item><note/></order>"))
!(test &doc
       (element order ((attr id "7"))
         ((element item ((attr sku "a")) ("apple"))
          (element item ((attr sku "b")) ("pear"))
          (element note () ()))))
; The shape is the interface: reading the items out of it needs no library call at
; all, only the children and a pattern. `superpose` holds its argument, so the
; children are bound first and superposed after.
!(test (collapse (let $children (index-atom &doc 3)
                   (let (element item ((attr sku $sku)) ($text)) (superpose $children)
                     ($sku $text))))
       (("a" "apple") ("b" "pear")))

; The three readers over an element. `markup-text` joins every text node under it,
; `markup-attribute` answers one attribute's value and has NO answer for an
; attribute the element does not carry.
!(test (markup-text &doc) "applepear")
!(test (markup-attribute &doc id) "7")
!(test (collapse (markup-attribute &doc missing)) ())
!(test (markup-text (element p () ())) "")

; The selector language. A step names elements and the three modifiers apply to
; the step they follow, which is how XPath itself spells them.
!(test (collapse (markup-select &doc ((descendant item) (text)))) ("apple" "pear"))
!(test (collapse (markup-select &doc ((descendant item) (attribute sku)))) ("a" "b"))
!(test (markup-select &doc ((descendant item) (index 2) (text))) "pear")
!(test (collapse (markup-select &doc (child item))) ((element item ((attr sku "a")) ("apple"))
                                                    (element item ((attr sku "b")) ("pear"))))
!(test (collapse (markup-select &doc (self order))) (&doc))
!(test (collapse (markup-select &doc (descendant missing))) ())
; A path walks down: child of a child, with the text of the last step.
!(bind! &nested (markup-parse-xml "<a><b><c>deep</c></b><c>shallow</c></a>"))
!(test (collapse (markup-select &nested ((child b) (child c) (text)))) ("deep"))
!(test (collapse (markup-select &nested ((descendant c) (text)))) ("shallow" "deep"))

; Writing inverts parsing: the text is the element's own markup, with no
; declaration and no layout, so it parses back to the same element.
!(test (markup-write (element item ((attr sku "a")) ("apple"))) "<item sku=\"a\">apple</item>")
!(test (markup-parse-xml (markup-write &doc)) &doc)
!(test (markup-write (element empty () ())) "<empty/>")
; An attribute value written as a Number or a Symbol becomes text, because that is
; all an XML attribute can hold.
!(test (markup-write (element a ((attr n 1) (attr k sym)) ())) "<a n=\"1\" k=\"sym\"/>")

; HTML's own rules are the host's: an omitted end tag HTML allows is not an error,
; so this parses and nests the second paragraph inside the first.
!(test (markup-parse-html "<p>one<p>two")
       (element p () ("one" (element p () ("two")))))
!(test (markup-text (markup-parse-html "<p>a<b>c</b></p>")) "ac")

; Every parse is STRICT, which is the difference between this library and the
; host's own reader: a missing end tag, a stray close tag and text outside any
; element are each repaired by the parser with a warning on stderr and a DOM
; anyway, and each is a refusal here.
!(test (if-error (catch (markup-parse-xml "<a><b></a>")) refused fine) refused)
!(test (if-error (catch (markup-parse-xml "<a>")) refused fine) refused)
!(test (if-error (catch (markup-parse-xml "not markup at all")) refused fine) refused)
!(test (if-error (catch (markup-parse-xml "")) refused fine) refused)
; An external entity is never fetched: the host refuses a SYSTEM entity and this
; turns the warning into an error, where it would otherwise answer an element with
; the entity's content silently missing.
!(test (if-error (catch (markup-parse-xml "<!DOCTYPE d [<!ENTITY e SYSTEM '/etc/passwd'>]><d>&e;</d>")) refused fine) refused)

; A selector the library does not know is refused with the five forms listed, and a
; modifier with no step before it has nothing to modify.
!(test (if-error (catch (markup-select &doc (nosuch item))) refused fine) refused)
!(test (if-error (catch (markup-select &doc ((text) (descendant item)))) refused fine) refused)
!(test (if-error (catch (markup-select &doc (index 1))) refused fine) refused)
; A value that is not an element is refused by every reader.
!(test (if-error (catch (markup-text 7)) refused fine) refused)
!(test (if-error (catch (markup-write (nosuch))) refused fine) refused)
