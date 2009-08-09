USING: accessors assocs arrays fry kernel lexer make math.parser
models monads namespaces parser sequences
sequences.extras models.combinators ui.gadgets
ui.gadgets.tracks words ;
QUALIFIED: make
QUALIFIED-WITH: ui.gadgets.books book
IN: ui.gadgets.layout
DEFER: with-interface

<PRIVATE

SYMBOL: templates
TUPLE: layout gadget size ; C: <layout> layout
TUPLE: placeholder < gadget members ;
: <placeholder> ( -- placeholder ) placeholder new V{ } clone >>members ;

: (remove-members) ( placeholder members -- ) [ [ model? ] filter swap parent>> model>> [ remove-connection ] curry each ]
    [ nip [ gadget? ] filter [ unparent ] each ] 2bi ;

: remove-members ( placeholder -- ) dup members>> [ drop ] [ [ (remove-members) ] keep delete-all ] if-empty ;
: add-member ( obj placeholder -- ) over layout? [ [ gadget>> ] dip ] when members>> push ;

: insertion-quot ( quot -- quot' ) make:building get [ [ placeholder? ] find-last nip [ <placeholder> dup , ] unless*
    templates get spin '[ [ _ templates set _ , @ ] with-interface ] ] when* ;

PRIVATE>

: , ( item -- ) make:, ;

SYNTAX: ,% scan string>number [ <layout> , ] curry over push-all ;
SYNTAX: ->% scan string>number '[ [ _ <layout> , ] [ output-model ] bi ] over push-all ;

GENERIC: -> ( uiitem -- model )
M: gadget -> dup , output-model ;
M: model -> dup , ;

: <spacer> ( -- ) <gadget> 1 <layout> , ;

<PRIVATE

: add-layout ( track layout -- track ) [ gadget>> ] [ size>> ] bi add-gadget* ;
: layouts ( sized? gadgets -- layouts ) [ [ gadget? ] [ layout? ] bi or ] filter swap
   [ [ dup layout? [ f <layout> ] unless ] map ]
   [ [ dup gadget? [ gadget>> ] unless ] map ] if ;
: make-layout ( building sized? -- models layouts ) [ swap layouts ] curry
   [ { } make [ [ model? ] filter ] ] dip bi ; inline
: <box> ( gadgets type -- track )
   [ t make-layout ] dip <track>
   swap [ add-layout ] each
   swap [ <collection> >>model ] unless-empty ; inline

: make-book ( models gadgets model -- book ) book:<book> swap [ "No models in books" throw ] unless-empty ;

ERROR: not-in-template word ;

PRIVATE>

: <hbox> ( gadgets -- track ) horizontal <box> ; inline
: <vbox> ( gadgets -- track ) vertical <box> ; inline

: <book> ( quot: ( -- model ) -- book ) f make-layout rot 0 >>value make-book ; inline
: <book*> ( quot -- book ) f make-layout f make-book ; inline

SYNTAX: $ CREATE-WORD dup
    [ [ dup templates get at [ nip , ] [ not-in-template ] if* ] curry (( -- )) define-declared "$" expect ]
    [ [ <placeholder> [ swap templates get set-at ] keep , ] curry ] bi over push-all ;

<PRIVATE
: insert-gadget ( number parent gadget -- ) -rot [ but-last insert-nth ] change-children drop ;
: insert-size ( number parent size -- ) -rot [ but-last insert-nth ] change-sizes drop ;
PRIVATE>
: insertion-point ( placeholder -- number parent ) dup parent>> [ children>> index ] keep ;

<PRIVATE
GENERIC: >layout ( gadget -- layout )
M: gadget >layout f <layout> ;
M: layout >layout ;
PRIVATE>

GENERIC# (add-gadget-at) 2 ( parent item n -- )
M: gadget (add-gadget-at) -rot [ add-gadget ] keep insert-gadget ;
M: track (add-gadget-at) -rot >layout [ add-layout ] keep [ gadget>> insert-gadget ] [ size>> insert-size ] 3bi ;

GENERIC# add-gadget-at 1 ( item location -- )
M: object add-gadget-at insertion-point -rot (add-gadget-at) ;
M: model add-gadget-at parent>> dup book:book? [ "No models in books" throw ]
   [ dup model>> dup collection? [ nip swap add-connection ] [ drop [ 1array <collection> ] dip (>>model) ] if ] if ;
: add-gadget*-at ( item location size -- ) swap [ <layout> ] dip add-gadget-at ;
: (add-gadget*-at) ( parent item n size -- ) swap [ <layout> ] dip (add-gadget-at) ;

<PRIVATE
: insert-item ( item location -- ) [ dup get [ drop ] [ remove-members ] if ] [ on ] [ ] tri
    [ add-member ] 2keep add-gadget-at ;

: insert-items ( makelist -- ) t swap [ dup placeholder? [ nip ] [ over insert-item ] if ] each drop ;
PRIVATE>

: with-interface ( quot -- ) [ { } make ] curry H{ } clone templates rot with-variable [ insert-items ] with-scope ; inline

M: model >>= [ swap insertion-quot <action> ] curry ;
M: model fmap insertion-quot <mapped> ;
M: model $> insertion-quot side-effect-model new-mapped-model ;
M: model <$ insertion-quot quot-model new-mapped-model ;