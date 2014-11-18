/*

NOTE: some stuff here have been taken from:
- https://raw2.github.com/antlr/grammars-v4/master/verilog/Verilog2001.g4
- https://github.com/gburdell/parser


Thanks go to Terrence Parr and Sam Harwell for making ANTLR and answering questions.
Thanks go also to gburdell for making a nice grammar that I could steal from.

Bug or misfeatures present in this grammar are my own.

TODO: currently skipping a lot of stuff inside modules/classes/interfaces/packages.

*/


parser grammar SVParser;
options {
	tokenVocab=SVLexer;
}
@header {
	package com.github.misfornoyd.systemverilog.generated;
}

source_text
	: (TIMESCALE | package_import_declaration | description)* EOF
	;

description
	: package_declaration
	| module_declaration
	| interface_declaration
	| class_declaration
	| program_declaration
	| attribute_instances package_item
	;

class_declaration
	: KW_VIRTUAL? KW_CLASS lifetime? class_identifier parameter_port_list?
	class_inherit?
	class_implement?
	SEMI
	class_body
	KW_ENDCLASS (COLON class_identifier)?
	;

class_inherit
	: KW_EXTENDS class_type (LPAREN list_of_arguments RPAREN)?
	;

class_implement
	: KW_IMPLEMENTS interface_class_type (COMMA interface_class_type)*
	;

class_body
	: class_item*
	;

class_item
	: attribute_instances class_property
	| attribute_instances class_method
	| attribute_instances class_constraint
	| attribute_instances class_declaration
	| attribute_instances covergroup_declaration
	| local_parameter_declaration SEMI
	| parameter_declaration SEMI
	| SEMI
	;

class_property
	: property_qualifier* data_declaration
	| KW_CONST class_item_qualifier* data_type const_identifier (EQ constant_expression)? SEMI
	;

class_method
	: method_qualifier* task_declaration
	| method_qualifier* function_declaration
	| KW_PURE KW_VIRTUAL class_item_qualifier* method_prototype SEMI
	| KW_EXTERN method_qualifier* method_prototype SEMI
	| method_qualifier* class_constructor_declaration
	| KW_EXTERN method_qualifier* class_constructor_prototype
	;

class_constructor_prototype
	: KW_FUNCTION KW_NEW (LPAREN tf_port_list? RPAREN)? SEMI
	;

class_constraint
	: constraint_prototype
	| constraint_declaration
	;

constraint_prototype
	: constraint_prototype_qualifier? KW_STATIC? KW_CONSTRAINT constraint_identifier SEMI
	;

cover_cross
	: (cross_identifier COLON)? KW_CROSS list_of_cross_items (KW_IFF LPAREN expression RPAREN)? cross_body
	;

list_of_cross_items
	: cross_item COMMA cross_item (COMMA cross_item)*
	;

cross_item
	: cover_point_identifier
	| variable_identifier
	;

cross_body
	: LCURLY cross_body_item* RCURLY // NOTE: bug in spec, can't have ; here.
	| SEMI
	;

cross_body_item
	: function_declaration
	| bins_selection_or_option SEMI
	;

constraint_prototype_qualifier
	: KW_EXTERN | KW_PURE
	;

class_item_qualifier
	: KW_STATIC
	| KW_PROTECTED
	| KW_LOCAL
	;

property_qualifier
	: random_qualifier
	| class_item_qualifier
	;

method_qualifier
	: KW_PURE? KW_VIRTUAL
	| class_item_qualifier
	;

method_prototype
	: task_prototype
	| function_prototype
	;

class_constructor_declaration
	: KW_FUNCTION class_scope? KW_NEW (LPAREN tf_port_list? RPAREN)? SEMI
	  block_item_declaration*
	  (KW_SUPER DOT KW_NEW (LPAREN list_of_arguments RPAREN)? SEMI)?
	  function_statement_or_null*
	  KW_ENDFUNCTION (COLON KW_NEW)?
	;

constraint_declaration
	: KW_STATIC? KW_CONSTRAINT constraint_identifier constraint_block
	;

interface_class_type
	: ps_class_identifier parameter_value_assignment?
	;

list_of_arguments
	: expression? (COMMA expression?)* (COMMA DOT identifier LPAREN expression? RPAREN)*
	| DOT identifier LPAREN expression? RPAREN (COMMA DOT identifier LPAREN expression? RPAREN)*
	;

program_declaration
	: program_nonansi_header timeunits_declaration? program_body KW_ENDPROGRAM (COLON program_identifier)?
	| program_ansi_header timeunits_declaration? program_body KW_ENDPROGRAM (COLON program_identifier)?
	| attribute_instances KW_PROGRAM program_identifier LPAREN DOT MUL RPAREN SEMI timeunits_declaration? program_body KW_ENDPROGRAM (COLON program_identifier)?
	| KW_EXTERN program_nonansi_header
	| KW_EXTERN program_ansi_header
	;

// TODO skip program contents for now.
program_body
	: (~KW_ENDPROGRAM)*?
	;

program_nonansi_header
	: attribute_instances KW_PROGRAM lifetime? program_identifier package_import_declaration* parameter_port_list? list_of_ports SEMI
	;

program_ansi_header
	: attribute_instances KW_PROGRAM lifetime? program_identifier package_import_declaration* parameter_port_list? list_of_port_declarations? SEMI
	;

package_declaration
	: attribute_instances KW_PACKAGE lifetime? package_identifier SEMI
	  timeunits_declaration? package_item* KW_ENDPACKAGE ( COLON package_identifier )?
	;

package_item
	: package_or_generate_item_declaration
	;

package_or_generate_item_declaration
	: data_declaration
	| class_declaration
	| function_declaration
	| task_declaration
	| dpi_import_export
	| local_parameter_declaration SEMI
	| parameter_declaration SEMI
	| covergroup_declaration
	| SEMI
	;

covergroup_declaration
	: KW_COVERGROUP covergroup_identifier (LPAREN tf_port_list? RPAREN)? coverage_event? SEMI
	  coverage_spec_or_option*
	  KW_ENDGROUP (COLON covergroup_identifier)?
	;

coverage_spec_or_option
	: attribute_instances coverage_spec
	| attribute_instances coverage_option SEMI
	;

coverage_option
	: KW_OPTION DOT member_identifier EQ expression
	| KW_TYPE_OPTION DOT member_identifier EQ constant_expression
	;

coverage_spec
	: cover_point
	| cover_cross
	;

coverage_event
	: clocking_event
	;

// NOTE: in the spec data_type_or_implicit is optional. It has an empty alternative however.
cover_point
	: (data_type_or_implicit cover_point_identifier COLON)? KW_COVERPOINT expression
	  (KW_IFF LPAREN expression RPAREN)?
	  bins_or_empty
	;

bins_or_empty
	: LCURLY attribute_instances (bins_or_options SEMI)* RCURLY
	| SEMI
	;

bins_or_options
	: coverage_option
	| KW_WILDCARD? bins_keyword bin_identifier (LSQUARE covergroup_expression? RSQUARE)? EQ LCURLY
	  covergroup_range_list* RCURLY (KW_WITH LPAREN with_covergroup_expression RPAREN)?
	  (KW_IFF LPAREN expression RPAREN)?
	| KW_WILDCARD? bins_keyword bin_identifier (LSQUARE covergroup_expression? RSQUARE)? EQ
	  cover_point_identifier (KW_WITH LPAREN with_covergroup_expression RPAREN)? (KW_IFF LPAREN expression RPAREN)?
	| KW_WILDCARD? bins_keyword bin_identifier (LSQUARE covergroup_expression? RSQUARE)? EQ
	  set_covergroup_expression (KW_IFF LPAREN expression RPAREN )?
	| KW_WILDCARD? bins_keyword bin_identifier (LSQUARE RSQUARE)? EQ trans_list (KW_IFF LPAREN expression RPAREN)?
	| bins_keyword bin_identifier (LSQUARE covergroup_expression? RSQUARE)? EQ KW_DEFAULT (KW_IFF RPAREN expression RPAREN)?
	| bins_keyword bin_identifier EQ KW_DEFAULT KW_SEQUENCE (KW_IFF LPAREN expression RPAREN)?
	;

bins_selection_or_option
	: attribute_instance* coverage_option
	| attribute_instance* bins_selection
	;

bins_selection
	: bins_keyword bin_identifier EQ select_expression (KW_IFF LPAREN expression RPAREN)?
	;

select_expression
	: select_condition
	| NOT select_condition
	| select_expression AND2 select_expression
	| select_expression OR2 select_expression
	| LPAREN select_expression RPAREN
	| select_expression KW_WITH LPAREN with_covergroup_expression RPAREN (KW_MATCHES integer_covergroup_expression)?
	| cross_identifier
	| cross_set_expression (KW_MATCHES integer_covergroup_expression)?
	;

select_condition
	: KW_BINSOF LPAREN bins_expression RPAREN (KW_INTERSECT LCURLY covergroup_range_list RCURLY)?
	;

bins_expression
	: variable_identifier
	| cover_point_identifier (DOT bin_identifier)?
	;

covergroup_range_list
	: covergroup_value_range (COMMA covergroup_value_range)*
	;

covergroup_value_range
	: covergroup_expression
	| LSQUARE covergroup_expression COLON covergroup_expression RSQUARE
	;

set_covergroup_expression
	: covergroup_expression
	;

with_covergroup_expression
	: covergroup_expression
	;

integer_covergroup_expression
	: covergroup_expression
	;

cross_set_expression
	: covergroup_expression
	;

covergroup_expression
	: expression
	;

trans_list
	: LPAREN trans_set RPAREN (COMMA LPAREN trans_set RPAREN)*
	;

trans_set
	: trans_range_list (EQ_GT trans_range_list)*
	;

trans_range_list
	: trans_item
	| trans_item LSQUARE * repeat_range RSQUARE
	| trans_item LSQUARE SUB_GT repeat_range RSQUARE
	| trans_item LSQUARE EQ repeat_range RSQUARE
	;

repeat_range
	: covergroup_expression
	| covergroup_expression COLON covergroup_expression
	;

trans_item
	: covergroup_range_list
	;

bins_keyword
	: KW_BINS | KW_ILLEGAL_BINS | KW_IGNORE_BINS
	;

data_declaration
	: KW_CONST? KW_VAR? lifetime? data_type_or_implicit list_of_variable_decl_assignments SEMI
	| type_declaration
	| package_import_declaration
//	| net_type_declaration  // TODO typo in A2.1.3?
	;

list_of_variable_decl_assignments
	: variable_decl_assignment (COMMA variable_decl_assignment)*
	;

variable_decl_assignment
	: variable_identifier variable_dimension* (EQ expression)?
	| dynamic_array_variable_identifier unsized_dimension variable_dimension* (EQ dynamic_array_new)?
	| class_variable_identifier (EQ class_new)?
	;

class_new
	: class_scope? KW_NEW (LPAREN list_of_arguments RPAREN)?
	| KW_NEW expression
	;

dynamic_array_new
	: KW_NEW LSQUARE expression RSQUARE (LPAREN expression RPAREN)?
	;

tf_item_declaration
	: block_item_declaration
	| tf_port_declaration
	;

block_item_declaration
	: attribute_instances data_declaration
	| attribute_instances local_parameter_declaration SEMI
	| attribute_instances parameter_declaration SEMI
	| attribute_instances overload_declaration
	| attribute_instances let_declaration
	;

let_declaration
	: KW_LET let_identifier ( LPAREN let_port_list? RPAREN )? EQ expression SEMI
	;

let_identifier
	: identifier
	;

let_port_list
	: let_port_item ( COMMA let_port_item )*
	;

let_port_item
	: attribute_instances let_formal_type formal_port_identifier ( EQ expression )?
	;

let_formal_type
	: data_type_or_implicit
	| KW_UNTYPED
	;

let_expression
//	: package_scope? let_identifier ( LPAREN let_list_of_arguments? RPAREN )? // TODO
	: package_scope? let_identifier
	;

let_list_of_arguments
	: let_actual_arg? ( COMMA let_actual_arg? )* ( COMMA DOT identifier LPAREN let_actual_arg? RPAREN )*
	| DOT identifier LPAREN let_actual_arg? RPAREN ( COMMA DOT identifier LPAREN let_actual_arg? RPAREN )*
	;

let_actual_arg
	: expression
	;

overload_declaration
	: KW_BIND overload_operator KW_FUNCTION data_type function_identifier
	  LPAREN overload_proto_formals RPAREN SEMI
	;

overload_operator
	: ADD | ADD2 | SUB | SUB2 | MUL | MUL2 | DIV | MOD | EQ2 | NOT_EQ
	| LT | LT_EQ | GT | GT_EQ | EQ
	;

overload_proto_formals
	: data_type ( COMMA data_type )*
	;

local_parameter_declaration
	: KW_LOCALPARAM data_type_or_implicit list_of_param_assignments
	| KW_LOCALPARAM KW_TYPE list_of_type_assignments
	;

parameter_declaration
	: KW_PARAMETER data_type_or_implicit list_of_param_assignments
	| KW_PARAMETER KW_TYPE list_of_type_assignments
	;

specparam_declaration
	: KW_SPECPARAM packed_dimension? list_of_specparam_assignments SEMI
	;

list_of_type_assignments
	: type_assignment ( COMMA type_assignment )*
	;

list_of_specparam_assignments
	: specparam_assignment ( COMMA specparam_assignment )*
	;

specparam_assignment
	: specparam_identifier EQ constant_mintypmax_expression
//	| pulse_control_specparam  // TODO
	;

type_assignment
	: type_identifier ( EQ data_type )?
	;

statement_or_null
	: statement
	| attribute_instances SEMI
	;

statement
	: (block_identifier COLON)? attribute_instances statement_item
	;

statement_item
	: blocking_assignment SEMI
	| nonblocking_assignment SEMI
	| procedural_continuous_assignment SEMI
	| case_statement
	| conditional_statement
	| inc_or_dec_expression SEMI
	| subroutine_call_statement
	| disable_statement
	| event_trigger
	| loop_statement
	| jump_statement
	| par_block
	| procedural_timing_control_statement
	| seq_block
	| wait_statement
	| procedural_assertion_statement
	| clocking_drive SEMI
	| randsequence_statement
	| randcase_statement
	| expect_property_statement
	;

concurrent_assertion_item
	: (block_identifier COLON)? concurrent_assertion_statement
	| checker_instantiation
	;

concurrent_assertion_statement
	: assert_property_statement
	| assume_property_statement
	| cover_property_statement
	| cover_sequence_statement
	| restrict_property_statement
	;

cover_sequence_statement
	: KW_COVER KW_SEQUENCE LPAREN clocking_event? (KW_DISABLE KW_IFF LPAREN expression_or_dist RPAREN)?
	  sequence_expr RPAREN statement_or_null
	;

restrict_property_statement
	: KW_RESTRICT KW_PROPERTY LPAREN property_spec RPAREN SEMI
	;

assert_property_statement
	: KW_ASSERT KW_PROPERTY LPAREN property_spec RPAREN action_block
	;

assume_property_statement
	: KW_ASSUME KW_PROPERTY LPAREN property_spec RPAREN action_block
	;

cover_property_statement
	: KW_COVER KW_PROPERTY LPAREN property_spec RPAREN statement_or_null
	;

expect_property_statement
	: KW_EXPECT LPAREN property_spec RPAREN action_block
	;

property_spec
	: clocking_event? (KW_DISABLE KW_IFF LPAREN expression_or_dist RPAREN)? property_expr
	;

property_expr
	: sequence_expr
	| KW_STRONG LPAREN sequence_expr RPAREN
	| KW_WEAK LPAREN sequence_expr RPAREN
	| LPAREN property_expr RPAREN
	| KW_NOT property_expr
	| property_expr KW_OR property_expr
	| property_expr KW_AND property_expr
	| sequence_expr OR_SUB_GT property_expr
	| sequence_expr OR_EQ_GT property_expr
	| KW_IF LPAREN expression_or_dist RPAREN property_expr (KW_ELSE property_expr)?
	| KW_CASE LPAREN expression_or_dist RPAREN property_case_item property_case_item* KW_ENDCASE
	| sequence_expr HASH_SUB_HASH property_expr
	| sequence_expr HASH_EQ_HASH property_expr
	| KW_NEXTTIME property_expr
	| KW_NEXTTIME LSQUARE constant_expression RSQUARE property_expr
	| KW_S_NEXTTIME property_expr
	| KW_S_NEXTTIME LSQUARE constant_expression RSQUARE property_expr
	| KW_ALWAYS property_expr
	| KW_ALWAYS LSQUARE cycle_delay_const_range_expression RSQUARE property_expr
	| KW_S_ALWAYS LSQUARE constant_range RSQUARE property_expr
	| KW_S_EVENTUALLY property_expr
	| KW_EVENTUALLY LSQUARE constant_range RSQUARE property_expr
	| KW_S_EVENTUALLY LSQUARE cycle_delay_const_range_expression RSQUARE property_expr
	| property_expr KW_UNTIL property_expr
	| property_expr KW_S_UNTIL property_expr
	| property_expr KW_UNTIL_WITH property_expr
	| property_expr KW_S_UNTIL_WITH property_expr
	| property_expr KW_IMPLIES property_expr
	| property_expr KW_IFF property_expr
	| KW_ACCEPT_ON LPAREN expression_or_dist RPAREN property_expr
	| KW_REJECT_ON LPAREN expression_or_dist RPAREN property_expr
	| KW_SYNC_ACCEPT_ON LPAREN expression_or_dist RPAREN property_expr
	| KW_SYNC_REJECT_ON LPAREN expression_or_dist RPAREN property_expr
	| property_instance
	| clocking_event property_expr
	;

property_case_item
	: expression_or_dist (COMMA expression_or_dist)* COLON property_expr SEMI?
	| KW_DEFAULT COLON? property_expr SEMI?
	;

property_instance
	: ps_or_hierarchical_property_identifier (LPAREN property_list_of_arguments? RPAREN)?
	;

property_list_of_arguments
	: DOT identifier LPAREN property_actual_arg? RPAREN (COMMA DOT identifier LPAREN property_actual_arg? RPAREN)*
	// Workaround for problematic optional blocks in spec grammar (alternative matching empty string).
	| property_actual_arg (COMMA property_actual_arg?)* (COMMA DOT identifier LPAREN property_actual_arg? RPAREN)*
	| (COMMA property_actual_arg?)+ (COMMA DOT identifier LPAREN property_actual_arg? RPAREN)*
	| (COMMA DOT identifier LPAREN property_actual_arg? RPAREN)+
	;

property_actual_arg
	: property_expr
	| sequence_actual_arg
	;

randsequence_statement
	: KW_RANDSEQUENCE LPAREN production_identifier? RPAREN production production* KW_ENDSEQUENCE
	;

production
	: data_type_or_void? production_identifier (LPAREN tf_port_list RPAREN)? COLON rs_rule (OR rs_rule)* SEMI
	;

rs_rule
	: rs_production_list (COLON_EQ weight_specification rs_code_block?)?
	;

rs_production_list
	: rs_prod rs_prod*
	| KW_RAND KW_JOIN (LPAREN expression RPAREN)? production_item production_item production_item*
	;

weight_specification
	: integral_number
	| ps_identifier
	| LPAREN expression RPAREN
	;

rs_code_block
	: LCURLY data_declaration* statement_or_null* RCURLY
	;

rs_prod
	: production_item
	| rs_code_block
	| rs_if_else
	| rs_repeat
	| rs_case
	;

production_item
	: production_identifier (LPAREN list_of_arguments RPAREN)?
	;

rs_if_else
	: KW_IF LPAREN expression RPAREN production_item (KW_ELSE production_item)?
	;

rs_repeat
	: KW_REPEAT LPAREN expression RPAREN production_item
	;

rs_case
	: KW_CASE LPAREN case_expression RPAREN rs_case_item rs_case_item* KW_ENDCASE
	;

rs_case_item
	: case_item_expression (COMMA case_item_expression)* COLON production_item SEMI
	| KW_DEFAULT COLON? production_item SEMI
	;

assertion_item
	: concurrent_assertion_item
	| deferred_immediate_assertion_item
	;

deferred_immediate_assertion_item
	: (block_identifier COLON)? deferred_immediate_assertion_statement
	;

procedural_assertion_statement
	: concurrent_assertion_statement
	| immediate_assertion_statement
	| checker_instantiation
	;

immediate_assertion_statement
	: simple_immediate_assertion_statement
	| deferred_immediate_assertion_statement
	;

simple_immediate_assertion_statement
	: simple_immediate_assert_statement
	| simple_immediate_assume_statement
	| simple_immediate_cover_statement
	;

simple_immediate_assert_statement
	: KW_ASSERT LPAREN expression RPAREN action_block
	;

simple_immediate_assume_statement
	: KW_ASSUME LPAREN expression RPAREN action_block
	;

simple_immediate_cover_statement
	: KW_COVER LPAREN expression RPAREN statement_or_null
	;

deferred_immediate_assertion_statement
	: deferred_immediate_assert_statement
	| deferred_immediate_assume_statement
	| deferred_immediate_cover_statement
	;

deferred_immediate_assert_statement
	: KW_ASSERT zero_delay LPAREN expression RPAREN action_block
	| KW_ASSERT KW_FINAL LPAREN expression RPAREN action_block
	;

deferred_immediate_assume_statement
	: KW_ASSUME zero_delay LPAREN expression RPAREN action_block
	| KW_ASSUME KW_FINAL LPAREN expression RPAREN action_block
	;

deferred_immediate_cover_statement
	: KW_COVER zero_delay LPAREN expression RPAREN statement_or_null
	| KW_COVER KW_FINAL LPAREN expression RPAREN statement_or_null
	;

zero_delay
	: HASH zero
	;

zero
	: {_input.LT(1).getText().matches("0")}? LIT_NUM
	;

checker_instantiation
	: ps_checker_identifier name_of_instance LPAREN list_of_checker_port_connections? RPAREN SEMI
	;

list_of_checker_port_connections
	: named_checker_port_connection (COMMA named_checker_port_connection)*
	// Workaround for problematic spec grammar rule.
	| ordered_checker_port_connection (COMMA ordered_checker_port_connection?)*
	| (COMMA ordered_checker_port_connection?)+
	;

ordered_checker_port_connection
	: attribute_instances property_actual_arg
	;

named_checker_port_connection
	: attribute_instances DOT formal_port_identifier (LPAREN property_actual_arg? RPAREN)?
	| attribute_instances DOT MUL
	;

name_of_instance
	: instance_identifier unpacked_dimension*
	;

loop_statement
	: KW_FOREVER statement_or_null
	| KW_REPEAT LPAREN expression RPAREN statement_or_null
	| KW_WHILE LPAREN expression RPAREN statement_or_null
	| KW_FOR LPAREN for_initialization? SEMI expression? SEMI for_step? RPAREN statement_or_null
	| KW_DO statement_or_null KW_WHILE LPAREN expression RPAREN SEMI
	| foreach statement
	;

// foreach seems illdefined. See e.g.:
// - http://www.eda.org/mantis/view.php?id=2932
// - http://www.eda.org/mantis/view.php?id=1712
// Real code uses multiple indexes.
// The thinking from the EDA people is that in the following 'foo[0]' is a hierarchical id, but it isn't:
// - foreach( foo[0][i] ).
foreach
	: KW_FOREACH LPAREN ps_or_hierarchical_array_identifier
	  (LSQUARE constant_expression RSQUARE)*
	  LSQUARE loop_variables? RSQUARE
	  RPAREN
	;

for_initialization
	: list_of_variable_assignments
	| for_variable_declaration (COMMA for_variable_declaration)*
	;

for_variable_declaration
	: KW_VAR? data_type variable_identifier EQ expression (COMMA variable_identifier EQ expression)*
	;

for_step
	: for_step_assignment (COMMA for_step_assignment)*
	;

for_step_assignment
	: operator_assignment
	| inc_or_dec_expression
	| function_subroutine_call
	;

loop_variables
	: index_variable_identifier (COMMA index_variable_identifier?)*
	| (COMMA index_variable_identifier?)+
	;

case_statement
	: unique_priority? case_keyword LPAREN case_expression RPAREN
	  case_item case_item* KW_ENDCASE
	| unique_priority? case_keyword LPAREN case_expression RPAREN KW_MATCHES
	  case_pattern_item case_pattern_item* KW_ENDCASE
	| unique_priority? KW_CASE LPAREN case_expression RPAREN KW_INSIDE
	  case_inside_item case_inside_item* KW_ENDCASE
	;

case_keyword
	: KW_CASE | KW_CASEZ | KW_CASEX
	;

case_expression
	: expression
	;

case_item
	: case_item_expression (COMMA case_item_expression)* COLON statement_or_null
	| KW_DEFAULT COLON? statement_or_null
	;

case_pattern_item
	: pattern (AND2 expression)? COLON statement_or_null
	| KW_DEFAULT COLON? statement_or_null
	;

case_inside_item
	: open_range_list COLON statement_or_null
	| KW_DEFAULT COLON? statement_or_null
	;

case_item_expression
	: expression
	;

randcase_statement
	: KW_RANDCASE randcase_item randcase_item* KW_ENDCASE
	;

randcase_item
	: expression COLON statement_or_null
	;

conditional_statement
	: unique_priority? KW_IF LPAREN cond_predicate RPAREN statement_or_null
	  (KW_ELSE KW_IF LPAREN cond_predicate RPAREN statement_or_null)*
	  (KW_ELSE statement_or_null)?
	  ;

unique_priority
	: KW_UNIQUE | KW_UNIQUE0 | KW_PRIORITY
	;

cond_predicate
	: expression_or_cond_pattern (AND3 expression_or_cond_pattern)*
	;

expression_or_cond_pattern
	: expression | cond_pattern
	;

cond_pattern
	: expression KW_MATCHES pattern
	;

constraint_block
	: LCURLY constraint_block_item* RCURLY
	;

constraint_block_item
	: KW_SOLVE solve_before_list KW_BEFORE solve_before_list SEMI
	| constraint_expression
	;

solve_before_list
	: constraint_primary (COMMA constraint_primary)*
	;

constraint_primary
	: (implicit_class_handle DOT | class_scope)? hierarchical_identifier select
	;

constraint_expression
	: KW_SOFT? expression_or_dist SEMI
	| uniqueness_constraint SEMI
	| expression SUB_GT constraint_set
	| KW_IF LPAREN expression RPAREN constraint_set (KW_ELSE constraint_set)?
	| foreach constraint_set
	| KW_DISABLE KW_SOFT constraint_primary SEMI
	;

uniqueness_constraint
	: KW_UNIQUE LCURLY open_range_list RCURLY
	;

open_range_list
	: open_value_range (COMMA open_value_range)*
	;

open_value_range
	: value_range
	;

constraint_set
	: constraint_expression
	| LCURLY constraint_expression* RCURLY
	;

action_block
	: statement_or_null
	| statement? KW_ELSE statement_or_null
	;

seq_block
	: KW_BEGIN ( COLON block_identifier )? block_item_declaration* statement_or_null*
	  KW_END ( COLON block_identifier )?
	;

par_block
	: KW_FORK (COLON block_identifier)? block_item_declaration* statement_or_null*
	  join_keyword (COLON block_identifier)?
	;

join_keyword
	: KW_JOIN | KW_JOIN_ANY | KW_JOIN_NONE
	;

function_statement
	: statement
	;

function_statement_or_null
	: function_statement
	| attribute_instances SEMI
	;

variable_identifier_list
	: variable_identifier ( COMMA variable_identifier )*
	;

initial_construct
	: KW_INITIAL statement_or_null
	;

always_construct
	: always_keyword statement
	;

always_keyword
	: KW_ALWAYS | KW_ALWAYS_COMB | KW_ALWAYS_LATCH | KW_ALWAYS_FF
	;

final_construct
	: KW_FINAL function_statement
	;

blocking_assignment
	: variable_lvalue EQ delay_or_event_control expression
	| nonrange_variable_lvalue EQ dynamic_array_new
	| ( (implicit_class_handle DOT) | class_scope | package_scope )? hierarchical_variable_identifier
	  select EQ class_new
	| operator_assignment
	;

implicit_class_handle
	: KW_THIS | KW_SUPER | KW_THIS DOT KW_SUPER
	;

genvar_expression
	: constant_expression
	;

operator_assignment
	: variable_lvalue assignment_operator expression
	;

assignment_operator
	: EQ | ADD_EQ | SUB_EQ | MUL_EQ | DIV_EQ | MOD_EQ | AND_EQ | OR_EQ
	| XOR_EQ | LT2_EQ | GT2_EQ | LT3_EQ | GT3_EQ
	;

nonblocking_assignment
	: variable_lvalue LT_EQ delay_or_event_control? expression
	;

procedural_continuous_assignment
	: KW_ASSIGN variable_assignment
	| KW_DEASSIGN variable_lvalue
	| KW_FORCE variable_assignment
	| KW_FORCE net_assignment
	| KW_RELEASE variable_lvalue
	| KW_RELEASE net_lvalue
	;

variable_assignment
	: variable_lvalue EQ expression
	;

continuous_assign
	: KW_ASSIGN drive_strength? delay3? list_of_net_assignments SEMI
	| KW_ASSIGN delay_control? list_of_variable_assignments SEMI
	;

list_of_net_assignments
	: net_assignment ( COMMA net_assignment )*
	;

list_of_variable_assignments
	: variable_assignment ( COMMA variable_assignment )*
	;

net_alias
	: KW_ALIAS net_lvalue EQ net_lvalue (EQ net_lvalue)* SEMI
	;

net_assignment
	: net_lvalue EQ expression
	;

delay3
	: HASH delay_value | HASH LPAREN mintypmax_expression ( COMMA mintypmax_expression ( COMMA mintypmax_expression )? )? RPAREN
	;

delay2
	: HASH delay_value | HASH LPAREN mintypmax_expression ( COMMA mintypmax_expression )? RPAREN
	;

delay_value
	: unsigned_number
	| real_number
	| ps_identifier
	| LIT_TIME
	| KW_1STEP
	;

drive_strength
	: LPAREN strength0 COMMA strength1 RPAREN
	| LPAREN strength1 COMMA strength0 RPAREN
	| LPAREN strength0 COMMA KW_HIGHZ1 RPAREN
	| LPAREN strength1 COMMA KW_HIGHZ0 RPAREN
	| LPAREN KW_HIGHZ0 COMMA strength1 RPAREN
	| LPAREN KW_HIGHZ1 COMMA strength0 RPAREN
	;

strength0
	: KW_SUPPLY0 | KW_STRONG0 | KW_PULL0 | KW_WEAK0
	;

strength1
	: KW_SUPPLY1 | KW_STRONG1 | KW_PULL1 | KW_WEAK1
	;

charge_strength
	: LPAREN KW_SMALL RPAREN
	| LPAREN KW_MEDIUM RPAREN
	| LPAREN KW_LARGE RPAREN
	;

procedural_timing_control_statement
	: procedural_timing_control statement_or_null
	;

delay_or_event_control
	: delay_control
	| event_control
	| KW_REPEAT LPAREN expression RPAREN event_control
	;

delay_control
	: HASH delay_value
	| HASH LPAREN mintypmax_expression RPAREN
	;

clocking_drive
	: clockvar_expression LT_EQ cycle_delay? expression
	;

clockvar
	: hierarchical_identifier
	;

clockvar_expression
	: clockvar select
	;

cycle_delay
	: HASH2 integral_number
	| HASH2 identifier
	| HASH2 LPAREN expression RPAREN
	;

sequence_instance
	: ps_or_hierarchical_sequence_identifier ( LPAREN sequence_list_of_arguments? RPAREN )?
	;

sequence_list_of_arguments
	: DOT identifier LPAREN sequence_actual_arg? RPAREN ( COMMA DOT identifier LPAREN sequence_actual_arg? RPAREN )*
	// Workaround for problematic spec grammar rule.
	| sequence_actual_arg (COMMA sequence_actual_arg?)* ( COMMA DOT identifier LPAREN sequence_actual_arg? RPAREN )*
	| (COMMA sequence_actual_arg?)+ ( COMMA DOT identifier LPAREN sequence_actual_arg? RPAREN )*
	| ( COMMA DOT identifier LPAREN sequence_actual_arg? RPAREN )+
	;

sequence_actual_arg
	: event_expression
	| sequence_expr
	;

sequence_expr
	: cycle_delay_range sequence_expr (cycle_delay_range sequence_expr)*
	| sequence_expr cycle_delay_range sequence_expr (cycle_delay_range sequence_expr)*
	| expression_or_dist boolean_abbrev?
	| sequence_instance sequence_abbrev?
	| LPAREN sequence_expr (COMMA sequence_match_item)* RPAREN sequence_abbrev?
	| sequence_expr KW_AND sequence_expr
	| sequence_expr KW_INTERSECT sequence_expr
	| sequence_expr KW_OR sequence_expr
	| KW_FIRST_MATCH LPAREN sequence_expr (COMMA sequence_match_item)* RPAREN
	| expression_or_dist KW_THROUGHOUT sequence_expr
	| sequence_expr KW_WITHIN sequence_expr
	| clocking_event sequence_expr
	;

clocking_event
	: AT_SIGN identifier
	| AT_SIGN LPAREN event_expression RPAREN
	;

sequence_method_call
	: sequence_instance DOT method_identifier
	;

sequence_match_item
	: operator_assignment
	| inc_or_dec_expression
	| subroutine_call
	;

inc_or_dec_expression
	: inc_or_dec_operator attribute_instances variable_lvalue
	| variable_lvalue attribute_instances inc_or_dec_operator
	;

inc_or_dec_operator
	: ADD2 | SUB2
	;

net_lvalue
	: ps_or_hierarchical_net_identifier constant_select
	| LCURLY net_lvalue (COMMA net_lvalue)* RCURLY
	| assignment_pattern_expression_type? assignment_pattern_net_lvalue
	;

variable_lvalue
	: (implicit_class_handle DOT | package_scope)? hierarchical_variable_identifier select
	| LCURLY variable_lvalue (COMMA variable_lvalue)* RCURLY
	| assignment_pattern_expression_type? assignment_pattern_variable_lvalue
	| streaming_concatenation
	;

pattern
	: DOT variable_identifier
	| DOT MUL
	| constant_expression
	| KW_TAGGED member_identifier pattern?
	| APOSTROPHE LCURLY pattern (COMMA pattern)* RCURLY
	| APOSTROPHE LCURLY member_identifier COLON pattern (COMMA member_identifier COLON pattern)* RCURLY
	;

assignment_pattern
	: APOSTROPHE LCURLY expression (COMMA expression)* RCURLY
	| APOSTROPHE LCURLY structure_pattern_key COLON expression (COMMA structure_pattern_key COLON expression)* RCURLY
	| APOSTROPHE LCURLY array_pattern_key COLON expression (COMMA array_pattern_key COLON expression)* RCURLY
	| APOSTROPHE LCURLY constant_expression LCURLY expression (COMMA expression)* RCURLY RCURLY
	;

structure_pattern_key
	: member_identifier | assignment_pattern_key
	;

array_pattern_key
	: constant_expression | assignment_pattern_key
	;

assignment_pattern_key
	: simple_type | KW_DEFAULT
	;

assignment_pattern_expression
	: assignment_pattern_expression_type? assignment_pattern
	;

assignment_pattern_expression_type
	: ps_type_identifier
	| ps_parameter_identifier
	| integer_atom_type
	| type_reference
	;

constant_assignment_pattern_expression
	: assignment_pattern_expression
	;

assignment_pattern_net_lvalue
	: APOSTROPHE LCURLY net_lvalue (COMMA net_lvalue)* RCURLY
	;

assignment_pattern_variable_lvalue
	: APOSTROPHE LCURLY variable_lvalue (COMMA variable_lvalue)* RCURLY
	;

nonrange_variable_lvalue
	: (implicit_class_handle DOT | package_scope)? hierarchical_variable_identifier nonrange_select
	;

constant_function_call
	: function_subroutine_call
	;

tf_call
	: ps_or_hierarchical_tf_identifier attribute_instances ( LPAREN list_of_arguments RPAREN )?
	;

system_tf_call
	: system_tf_identifier ( LPAREN list_of_arguments RPAREN )?
	| system_tf_identifier LPAREN data_type (COMMA expression)? RPAREN
	;

subroutine_call
	: tf_call
	| system_tf_call
	| static_method_call // see issue #20
	| method_call
	| randomize_call
	;

subroutine_call_statement
	: subroutine_call SEMI
	| KW_VOID APOSTROPHE LPAREN function_subroutine_call RPAREN SEMI
	;

function_subroutine_call
	: subroutine_call
	;

built_in_method_call
	: array_manipulation_call
	| randomize_call
	;

array_manipulation_call
	: array_method_name attribute_instances
	  (LPAREN list_of_arguments RPAREN)?
	  (KW_WITH LPAREN expression RPAREN)?
	;

randomize_call
	: (KW_STD COLON2)? KW_RANDOMIZE attribute_instances
	  (LPAREN (variable_identifier_list | KW_NULL)? RPAREN)?
	  (KW_WITH (LPAREN identifier_list? RPAREN)? constraint_block)?
	  ;

array_method_name
	: method_identifier | KW_UNIQUE | KW_AND | KW_OR | KW_XOR
	;

cycle_delay_range
	: HASH2 constant_primary
	| HASH2 LSQUARE cycle_delay_const_range_expression RSQUARE
	| HASH2 LSQUARE MUL RSQUARE
	| HASH2 LSQUARE ADD RSQUARE
	;

cycle_delay_const_range_expression
	: constant_expression COLON constant_expression
	| constant_expression COLON DOLLAR
	;

boolean_abbrev
	: consecutive_repetition
	| non_consecutive_repetition
	| goto_repetition
	;

sequence_abbrev
	: consecutive_repetition
	;

consecutive_repetition
	: LSQUARE MUL const_or_range_expression RSQUARE
	| LSQUARE MUL RSQUARE
	| LSQUARE ADD RSQUARE
	;

non_consecutive_repetition
	: LSQUARE EQ const_or_range_expression RSQUARE
	;

goto_repetition
	: LSQUARE SUB_GT const_or_range_expression LSQUARE
	;

const_or_range_expression
	: constant_expression
	| cycle_delay_const_range_expression
	;

expression_or_dist
	: expression ( KW_DIST LCURLY dist_list RCURLY )?
	;

dist_list
	: dist_item (COMMA dist_item )*
	;

dist_item
	: value_range dist_weight?
	;

value_range
	: expression
	| LSQUARE expression COLON expression RSQUARE
	;

dist_weight
	: COLON_EQ expression
	| COLON_DIV expression
	;

event_control
	: AT_SIGN hierarchical_event_identifier
	| AT_SIGN LPAREN event_expression RPAREN
	| AT_SIGN MUL
	| AT_SIGN LPAREN MUL RPAREN
	| AT_SIGN ps_or_hierarchical_sequence_identifier
	;

event_expression
	: edge_identifier? expression (KW_IFF expression)?
	| sequence_instance (KW_IFF expression)?
	| event_expression KW_OR event_expression
	| event_expression COMMA event_expression
	| LPAREN event_expression RPAREN
	;

edge_identifier
	: KW_POSEDGE | KW_NEGEDGE | KW_EDGE
	;

procedural_timing_control
	: delay_control
	| event_control
	| cycle_delay
	;

jump_statement
	: KW_RETURN expression? SEMI
	| KW_BREAK SEMI
	| KW_CONTINUE SEMI
	;

wait_statement
	: KW_WAIT LPAREN expression RPAREN statement_or_null
	| KW_WAIT KW_FORK SEMI
	| KW_WAIT_ORDER LPAREN hierarchical_identifier (COMMA hierarchical_identifier)* RPAREN action_block
	;

// NOTE: see issue #24
event_trigger
	: SUB_GT expression SEMI
	| SUB_GT2 delay_or_event_control? expression SEMI
	;

disable_statement
	: KW_DISABLE hierarchical_task_identifier SEMI
	| KW_DISABLE hierarchical_block_identifier SEMI
	| KW_DISABLE KW_FORK SEMI
	;

dpi_import_export
	: KW_IMPORT dpi_spec_string dpi_function_import_property? (c_identifier EQ)? dpi_function_proto SEMI
	| KW_IMPORT dpi_spec_string dpi_task_import_property? (c_identifier EQ)? dpi_task_proto SEMI
	| KW_EXPORT dpi_spec_string (c_identifier EQ)? KW_FUNCTION function_identifier SEMI
	| KW_EXPORT dpi_spec_string (c_identifier EQ)? KW_TASK task_identifier SEMI
	;

dpi_spec_string
	: {_input.LT(1).getText().matches("DPI-C")}? LIT_STRING
	| {_input.LT(1).getText().matches("DPI")}? LIT_STRING
	;

dpi_function_import_property
	: KW_CONTEXT | KW_PURE
	;

dpi_task_import_property
	: KW_CONTEXT
	;

dpi_function_proto
	: function_prototype
	;

dpi_task_proto
	: task_prototype
	;

task_declaration
	: KW_TASK lifetime? task_name_qualifier? task_identifier task_body_declaration
	;

task_body_declaration
	: SEMI
	  tf_item_declaration*
	  statement_or_null*
	  KW_ENDTASK ( COLON task_identifier )?
	| LPAREN tf_port_list? RPAREN SEMI
	  block_item_declaration*
	  statement_or_null*
	  KW_ENDTASK ( COLON task_identifier )?
	;

function_declaration
	: KW_FUNCTION lifetime? function_data_type_or_implicit function_name_qualifier? function_identifier
	  function_body_declaration
	  KW_ENDFUNCTION ( COLON function_identifier )?
	;

task_name_qualifier
	: function_name_qualifier
	;

function_name_qualifier
	: interface_identifier DOT
	| (package_scope parameter_value_assignment?)? (class_identifier parameter_value_assignment? COLON2)+
	;

function_body_declaration
	: SEMI
	  tf_item_declaration*
	  function_statement_or_null*
	| LPAREN tf_port_list? RPAREN SEMI
	  block_item_declaration*
	  function_statement_or_null*
	;

function_prototype
	: KW_FUNCTION function_data_type_or_implicit function_identifier ( LPAREN tf_port_list? RPAREN )?
	;

function_data_type_or_implicit
	: data_type_or_void | implicit_data_type
	;

data_type_or_void
	: data_type | KW_VOID
	;

type_reference
	: KW_TYPE LPAREN expression RPAREN
	| KW_TYPE LPAREN data_type RPAREN
	;

port_direction
	: KW_INPUT | KW_OUTPUT | KW_INOUT | KW_REF
	;

tf_port_list
	: tf_port_item (COMMA tf_port_item)*
	;

tf_port_item
	: attribute_instances tf_port_direction? KW_VAR? data_type_or_implicit
	  port_identifier variable_dimension* (EQ expression)?
	;

tf_port_direction
	: port_direction
	| KW_CONST KW_REF
	;

tf_port_declaration
	: attribute_instances tf_port_direction KW_VAR? data_type_or_implicit list_of_tf_variable_identifiers SEMI
	;

task_prototype
	: KW_TASK task_identifier ( LPAREN tf_port_list? RPAREN )?
	;

module_declaration
	: module_declaration_non_ansi
	| module_declaration_ansi
	;

module_declaration_non_ansi
	: attribute_instances module_keyword module_identifier ( parameter_port_list )? ( list_of_ports )? SEMI
	  module_body KW_ENDMODULE ( COLON module_identifier )?
    ;

module_declaration_ansi
	: attribute_instances module_keyword module_identifier ( parameter_port_list )? ( list_of_port_declarations )? SEMI
	  module_body KW_ENDMODULE ( COLON module_identifier )?
	;

// TODO skip module contents for now.
module_body
	: (~KW_ENDMODULE)*?
	;

module_keyword
	: KW_MODULE | KW_MACROMODULE
	;

interface_declaration
	: interface_nonansi_header timeunits_declaration? interface_body
		KW_ENDINTERFACE ( COLON interface_identifier )?
	| interface_ansi_header timeunits_declaration? interface_body
 		KW_ENDINTERFACE ( COLON interface_identifier )?
	| attribute_instances KW_INTERFACE interface_identifier LPAREN DOT MUL RPAREN SEMI
		timeunits_declaration? interface_body
 		KW_ENDINTERFACE ( COLON interface_identifier )?
	| KW_EXTERN interface_nonansi_header
	| KW_EXTERN interface_ansi_header
	;

interface_nonansi_header
	: attribute_instances KW_INTERFACE lifetime? interface_identifier
		package_import_declaration* parameter_port_list? list_of_ports SEMI
	;
interface_ansi_header
	: attribute_instances KW_INTERFACE lifetime? interface_identifier
		package_import_declaration* parameter_port_list? list_of_port_declarations? SEMI
	;

type_declaration
	: KW_TYPEDEF data_type type_identifier variable_dimension* SEMI
	| KW_TYPEDEF interface_instance_identifier constant_bit_select DOT type_identifier type_identifier SEMI
	| KW_TYPEDEF ( KW_ENUM | KW_STRUCT | KW_UNION | KW_CLASS | KW_INTERFACE KW_CLASS )? type_identifier SEMI
	;

constant_bit_select
	: ( LSQUARE constant_expression RSQUARE )*
	;

constant_select
	: ( ( DOT member_identifier constant_bit_select)* DOT member_identifier)? constant_bit_select
	  (LSQUARE constant_part_select_range RSQUARE)?
	;

lifetime
	: KW_STATIC | KW_AUTOMATIC
	;

timeunits_declaration
	: KW_TIMEUNIT LIT_TIME ( DIV LIT_TIME )? SEMI
	| KW_TIMEPRECISION LIT_TIME SEMI
	| KW_TIMEUNIT LIT_TIME SEMI KW_TIMEPRECISION LIT_TIME SEMI
	| KW_TIMEPRECISION LIT_TIME SEMI KW_TIMEUNIT LIT_TIME SEMI
	;

// TODO skip interface contents for now.
interface_body
	: (~KW_ENDINTERFACE)*?
	;

package_import_declaration
	: KW_IMPORT package_import_item ( COMMA package_import_item )* SEMI
	;
package_import_item
	: package_identifier COLON2 identifier
	| package_identifier COLON2 MUL
	;

parameter_port_list
	: HASH LPAREN list_of_param_assignments (COMMA parameter_port_declaration)* RPAREN
	| HASH LPAREN parameter_port_declaration (COMMA parameter_port_declaration)* RPAREN
	| HASH LPAREN RPAREN
	;

parameter_port_declaration
	: parameter_declaration
	| local_parameter_declaration
	| data_type list_of_param_assignments
	| KW_TYPE list_of_type_assignments
	;

list_of_ports
	: LPAREN port ( COMMA port )* RPAREN
	;

port_declaration
	: attribute_instances
		( inout_declaration
		| input_declaration
		| output_declaration
		| ref_declaration
		| interface_port_declaration
		)
	;

list_of_port_declarations
	: LPAREN port_declaration ( COMMA port_declaration )* RPAREN
	| LPAREN RPAREN
	;

port: port_expression?
	| DOT port_identifier LPAREN ( port_expression )? RPAREN
	;

port_expression
	: port_reference
	| LCURLY port_reference ( COMMA port_reference )* RCURLY
	;

port_reference
	: port_identifier
	| port_identifier LSQUARE constant_expression RSQUARE
	| port_identifier LSQUARE range_expression RSQUARE
	;

ref_declaration
	: KW_REF data_type list_of_port_identifiers
	;

interface_port_declaration
	: interface_identifier list_of_interface_identifiers
	| interface_identifier DOT modport_identifier list_of_interface_identifiers
	;

list_of_param_assignments
	: param_assignment ( COMMA param_assignment )*
	;

param_assignment
	: parameter_identifier EQ constant_expression
	;

inout_declaration
	: KW_INOUT ( net_type )? ( KW_SIGNED )? ( range )? list_of_port_identifiers
	;
input_declaration
	: KW_INPUT ( net_type )? ( KW_SIGNED )? ( range )? list_of_port_identifiers
	| KW_INPUT variable_port_type list_of_variable_identifiers
	;
output_declaration
	: KW_OUTPUT ( net_type )? ( KW_SIGNED )? ( range )? list_of_port_identifiers
	| KW_OUTPUT variable_port_type list_of_variable_identifiers
	;

list_of_variable_identifiers
	: variable_identifier variable_dimension? ( COMMA variable_identifier variable_dimension? )*
	;

list_of_interface_identifiers
	: interface_identifier ( unpacked_dimension )* ( COMMA interface_identifier ( unpacked_dimension )* )*
	;

list_of_port_identifiers
	: port_identifier ( COMMA port_identifier )*
	;

list_of_variable_port_identifiers
	:  port_identifier ( EQ constant_expression )? ( COMMA port_identifier ( EQ constant_expression )? )*
	;

list_of_tf_variable_identifiers
	: port_identifier variable_dimension* (EQ expression)?
	  ( COMMA port_identifier variable_dimension* (EQ expression)? )*
	;

net_type
	: KW_SUPPLY0 | KW_SUPPLY1 | KW_TRI | KW_TRIAND | KW_TRIOR | KW_TRIREG | KW_TRI0 | KW_TRI1 | KW_UWIRE | KW_WIRE | KW_WAND | KW_WOR
	;

integer_type
	: integer_vector_type | integer_atom_type
	;

integer_atom_type
	: KW_BYTE | KW_SHORTINT | KW_INT | KW_LONGINT | KW_INTEGER | KW_TIME
	;

integer_vector_type
	: KW_BIT | KW_LOGIC | KW_REG
	;

non_integer_type
	: KW_SHORTREAL | KW_REAL | KW_REALTIME
	;

output_variable_type
	: KW_INTEGER | KW_TIME
	;

variable_port_type
	: var_data_type
	;

var_data_type
	: KW_VAR data_type_or_implicit
	| data_type
	;

data_type_or_implicit
	: data_type
	| implicit_data_type
	;

implicit_data_type
	: signing? packed_dimension*
	;

// TODO
data_type
	: integer_vector_type signing? packed_dimension*
	| integer_atom_type signing?
	| non_integer_type
	| struct_union (KW_PACKED signing?)? LCURLY struct_union_member+ RCURLY packed_dimension*
	| KW_ENUM enum_base_type? LCURLY enum_name_declaration (COMMA enum_name_declaration)* RCURLY packed_dimension*
	| KW_STRING
	| KW_CHANDLE
	| KW_VIRTUAL KW_INTERFACE? interface_identifier parameter_value_assignment? (DOT modport_identifier)?
	| (class_scope | package_scope)? type_identifier packed_dimension*
	| class_type
	| KW_EVENT
	| ps_covergroup_identifier
	| type_reference
	;

struct_union
	: KW_STRUCT | KW_UNION KW_TAGGED?
	;

struct_union_member
	: attribute_instances random_qualifier? data_type_or_void list_of_variable_decl_assignments SEMI
	;

random_qualifier
	: KW_RAND | KW_RANDC
	;

simple_type
	: integer_type | non_integer_type | ps_type_identifier | ps_parameter_identifier
	;

enum_base_type
	: integer_atom_type ( signing )?
	| integer_vector_type ( signing )? ( packed_dimension )?
	| type_identifier ( packed_dimension )?
	;

enum_name_declaration
	: enum_identifier
	( LSQUARE integral_number ( COLON integral_number )? RSQUARE )?
	( EQ constant_expression )?
	;

parameter_value_assignment
	: HASH LPAREN (list_of_parameter_assignments)? RPAREN
	;

list_of_parameter_assignments
	: ordered_parameter_assignment ( COMMA ordered_parameter_assignment )*
	| named_parameter_assignment ( COMMA named_parameter_assignment )*
	;

ordered_parameter_assignment
	: param_expression
	;

named_parameter_assignment
	: DOT parameter_identifier LPAREN ( param_expression )? RPAREN
	;

signing
	: KW_SIGNED | KW_UNSIGNED
	;

unpacked_dimension
	: LSQUARE constant_range RSQUARE
	| LSQUARE constant_expression RSQUARE
	;

packed_dimension
	: LSQUARE constant_range RSQUARE
	| unsized_dimension
	;

associative_dimension
	: LSQUARE data_type RSQUARE
	| LSQUARE MUL RSQUARE
	;

variable_dimension
	: unsized_dimension
	| unpacked_dimension
	| associative_dimension
	| queue_dimension
	;

queue_dimension
	: LSQUARE DOLLAR ( COLON constant_expression )? RSQUARE
	;

unsized_dimension
	: LSQUARE RSQUARE
	;

sized_or_unsized_dimension
	: unpacked_dimension | unsized_dimension
	;

constant_part_select_range
	: constant_range
	| constant_indexed_range
	;

constant_indexed_range
	: constant_expression ADD_COLON constant_expression
	| constant_expression SUB_COLON constant_expression
	;

dimension : LSQUARE dimension_constant_expression COLON dimension_constant_expression RSQUARE ;
range : LSQUARE msb_constant_expression COLON lsb_constant_expression RSQUARE ;
constant_range : constant_expression COLON constant_expression ;

concatenation : LCURLY expression ( COMMA expression )* RCURLY ;
constant_concatenation : LCURLY constant_expression ( COMMA constant_expression )* RCURLY ;
constant_multiple_concatenation : LCURLY constant_expression constant_concatenation RCURLY ;
module_path_concatenation : LCURLY module_path_expression ( COMMA module_path_expression )* RCURLY ;
module_path_multiple_concatenation : LCURLY constant_expression module_path_concatenation RCURLY ;
multiple_concatenation : LCURLY constant_expression concatenation RCURLY ;
streaming_concatenation : LCURLY stream_operator slice_size? stream_concatenation RCURLY ;
stream_operator : GT2 | LT2 ;
slice_size : simple_type | constant_expression ;
stream_concatenation : LCURLY stream_expression (COMMA stream_expression)* RCURLY ;
stream_expression : expression (KW_WITH LSQUARE array_range_expression RSQUARE)? ;

array_range_expression
	: expression
	| expression COLON expression
	| expression ADD_COLON expression
	| expression SUB_COLON expression
	;

empty_queue : LCURLY RCURLY ;

net_concatenation : LCURLY net_concatenation_value ( COMMA net_concatenation_value )* RCURLY ;

net_concatenation_value
	: hierarchical_net_identifier
	| hierarchical_net_identifier LSQUARE expression RSQUARE ( LSQUARE expression RSQUARE )*
	| hierarchical_net_identifier LSQUARE expression RSQUARE ( LSQUARE expression RSQUARE )* LSQUARE range_expression RSQUARE
	| hierarchical_net_identifier LSQUARE range_expression RSQUARE
	| net_concatenation
	;

variable_concatenation
	: LCURLY variable_concatenation_value ( COMMA variable_concatenation_value )* RCURLY
	;

variable_concatenation_value
	: hierarchical_variable_identifier
	| hierarchical_variable_identifier LSQUARE expression RSQUARE ( LSQUARE expression RSQUARE )*
	| hierarchical_variable_identifier LSQUARE expression RSQUARE ( LSQUARE expression RSQUARE )* LSQUARE range_expression RSQUARE
	| hierarchical_variable_identifier LSQUARE range_expression RSQUARE
	| variable_concatenation
	;

base_expression
	: expression
	;

constant_base_expression
	: constant_expression
	;

// NOTE: this causes hierarchical_id to match "foo[i].bar".
constant_expression
	: expression
	;

constant_mintypmax_expression
	: constant_expression
	| constant_expression QUE constant_expression QUE constant_expression
	;

constant_range_expression
	: constant_expression
	| msb_constant_expression QUE lsb_constant_expression
	| constant_base_expression ADD_COLON width_constant_expression
	| constant_base_expression SUB_COLON width_constant_expression
	;

dimension_constant_expression
	: constant_expression
	;

param_expression
	: mintypmax_expression
	| data_type
	;

expression
	: term (
	      binary_operator attribute_instances term
	    | QUE attribute_instances expression COLON term
	  )*
	;

term
	: (primary
	| unary_operator attribute_instances primary
	| inc_or_dec_expression
	) inside_expression?
	;

inside_expression
	: KW_INSIDE LCURLY open_range_list RCURLY
	;

lsb_constant_expression
	: constant_expression
	;

mintypmax_expression
	: expression (QUE expression QUE expression)?
	;

module_path_conditional_expression
	: module_path_expression QUE attribute_instances module_path_expression
	  QUE module_path_expression
	;

module_path_expression
	: ( module_path_primary
	  | unary_module_path_operator attribute_instances module_path_primary
	  )
	  ( binary_module_path_operator attribute_instances module_path_expression
	  | QUE attribute_instances module_path_expression QUE module_path_expression
	  )*
	;

module_path_mintypmax_expression
	: module_path_expression (QUE module_path_expression QUE module_path_expression)?
	;

msb_constant_expression
	: constant_expression
	;

range_expression
	: expression
	| msb_constant_expression QUE lsb_constant_expression
	| base_expression ADD_COLON width_constant_expression
	| base_expression SUB_COLON width_constant_expression
	;

width_constant_expression
	: constant_expression
	;

constant_primary
	: constant_concatenation
	| constant_function_call
	| LPAREN constant_mintypmax_expression RPAREN
	| constant_multiple_concatenation
	| genvar_identifier
	| number
	| parameter_identifier
	| specparam_identifier
	;

module_path_primary
	: number
	| identifier
	| module_path_concatenation
	| module_path_multiple_concatenation
	| function_subroutine_call
	| LPAREN module_path_mintypmax_expression RPAREN
	;

// TODO
primary
	: primary_literal
	| identifier_primary
	| empty_queue
	| concatenation (LSQUARE range_expression RSQUARE)?
	| multiple_concatenation (LSQUARE range_expression RSQUARE)?
	| function_subroutine_call
	| LPAREN mintypmax_expression RPAREN
	| cast
	| assignment_pattern_expression
	| streaming_concatenation
	| sequence_method_call
	| KW_THIS
	| DOLLAR
	| KW_NULL
	;

primary_literal
	: number | LIT_TIME | LIT_UNBASED_UNSIZED | LIT_STRING
	;

cast
	: casting_type APOSTROPHE LPAREN expression RPAREN
	;

casting_type
	: simple_type | constant_primary | signing | KW_STRING | KW_CONST
	;

identifier_primary
	: (class_qualifier | package_scope)? hierarchical_identifier select
	;

select
	: ( ( DOT member_identifier bit_select )* DOT member_identifier )? bit_select
	  ( LSQUARE part_select_range RSQUARE )?
	;

bit_select
	: (LSQUARE expression RSQUARE)*
	;

nonrange_select
	: ( (DOT member_identifier bit_select)* DOT member_identifier )? bit_select
	;

part_select_range
	: constant_range | indexed_range
	;

indexed_range
	: expression ADD_COLON constant_expression
	| expression SUB_COLON constant_expression
	;

class_qualifier
	: (KW_LOCAL COLON2)? (implicit_class_handle DOT | class_scope)
	;

// TODO bug #16, primary and method_call_root are mutually left-recursive in spec grammar.
// method call root can be an expression
// See also: http://www.eda.org/svdb/view.php?id=1480
primary_call_root
	: identifier_primary attribute_instances (LPAREN list_of_arguments RPAREN)?
	;

method_call_root
	: primary_call_root | implicit_class_handle
	;

method_call
	: method_call_root DOT method_call_body
	;

method_call_body
	: method_identifier attribute_instances (LPAREN list_of_arguments RPAREN)?
	| built_in_method_call
	;

// TODO static method call root can be a primary
// TODO generic calls need to be fixed.
static_method_call
	: (package_identifier COLON2)?
	  (class_identifier parameter_value_assignment? COLON2)+
	  method_identifier
	  (LPAREN list_of_arguments RPAREN)?
	;

class_scope
	: class_type COLON2
	;

class_type
	: ps_class_identifier parameter_value_assignment? (COLON2 class_identifier parameter_value_assignment?)*
	;

ps_class_identifier
	: package_scope? class_identifier
	;

package_scope
	: (package_identifier | DOLLAR_UNIT) COLON2
	;

unary_operator
	: ADD | SUB | NOT | INV | AND | INV_AND | OR | INV_OR | XOR | INV_XOR | XOR_INV
	;

binary_operator
	: ADD | SUB | MUL | DIV | MOD | EQ2 | NOT_EQ | EQ3 | NOT_EQ2
	| AND2 | OR2 | MUL2 | LT | LT_EQ | GT | GT_EQ | AND | OR | XOR
	| XOR_INV | INV_XOR | GT2 | LT2 | GT3 | LT3
	;

unary_module_path_operator
	: NOT | INV | AND | INV_AND | OR | INV_OR | XOR | INV_XOR | XOR_INV
	;

binary_module_path_operator
	: EQ2 | NOT_EQ | AND2 | OR2 | AND | OR | XOR | XOR_INV | INV_XOR
	;

// TODO
number : LIT_NUM ;
decimal_number : LIT_NUM ;
integral_number : number ;
real_number : number ;
unsigned_number : number ;

identifier_list
	: identifier (COMMA identifier)*
	;

escaped_identifier : simple_identifier ; // TODO
simple_identifier : ID | KW_STD | KW_NEW ;

arrayed_identifier : simple_arrayed_identifier | escaped_arrayed_identifier ;
block_identifier : identifier ;
cell_identifier : identifier ;
config_identifier : identifier ;
escaped_arrayed_identifier : escaped_identifier ( range )? ;
event_identifier : identifier ;
gate_instance_identifier : arrayed_identifier ;
generate_block_identifier : identifier ;
genvar_function_identifier : identifier ;
genvar_identifier : identifier ;
hierarchical_block_identifier : hierarchical_identifier ;
hierarchical_event_identifier : hierarchical_identifier ;
hierarchical_function_identifier : hierarchical_identifier ;
hierarchical_net_identifier : hierarchical_identifier ;
hierarchical_variable_identifier : hierarchical_identifier ;
hierarchical_task_identifier : hierarchical_identifier ;
hierarchical_sequence_identifier : hierarchical_identifier ;
hierarchical_property_identifier : hierarchical_identifier ;
identifier : simple_identifier | escaped_identifier ;
inout_port_identifier : identifier ;
input_port_identifier : identifier ;
instance_identifier : identifier ;
interface_identifier : identifier ;
package_identifier : identifier ;
library_identifier : identifier ;
memory_identifier : identifier ;
module_identifier : identifier ;
module_instance_identifier : arrayed_identifier ;
net_identifier : identifier ;
output_port_identifier : identifier ;
parameter_identifier : identifier ;
port_identifier : identifier ;
real_identifier : identifier ;
simple_arrayed_identifier : simple_identifier ( range )? ;
specparam_identifier : identifier ;
dollar_Identifier : SYSTEM_ID ;
system_function_identifier : dollar_Identifier ;
system_task_identifier : dollar_Identifier ;
task_identifier : identifier ;
terminal_identifier : identifier ;
text_macro_identifier : simple_identifier ;
topmodule_identifier : identifier ;
udp_identifier : identifier ;
udp_instance_identifier : arrayed_identifier ;
variable_identifier : identifier ;
type_identifier : identifier ;
class_identifier : identifier ;
modport_identifier : identifier ;
program_identifier : identifier ;
interface_instance_identifier : identifier ;
dynamic_array_variable_identifier : variable_identifier ;
class_variable_identifier : variable_identifier ;
enum_identifier : identifier ;
formal_port_identifier : identifier ;
sequence_identifier : identifier ;
member_identifier : identifier ;
hierarchical_tf_identifier : hierarchical_identifier ;
system_tf_identifier : SYSTEM_ID ;
tf_identifier : identifier ;
hierarchical_array_identifier : hierarchical_identifier ;
index_variable_identifier : identifier ;
production_identifier : identifier ;
property_identifier : identifier ;
checker_identifier : identifier ;
covergroup_identifier : identifier ;
const_identifier : identifier ;
constraint_identifier : identifier ;
bin_identifier : identifier ;
cover_point_identifier : identifier ;
cross_identifier : identifier ;

ps_covergroup_identifier
	: package_scope? covergroup_identifier
	;

// TODO not strictly correct
c_identifier : identifier ;

method_identifier : identifier ;
function_identifier : identifier ;

hierarchical_identifier
	: (DOLLAR_ROOT DOT)? (identifier constant_bit_select DOT)* identifier
	;

ps_identifier
	: package_scope? identifier
	;

ps_checker_identifier
	: package_scope? checker_identifier
	;

ps_or_hierarchical_array_identifier
	: (implicit_class_handle DOT | class_scope | package_scope)? hierarchical_array_identifier
	;

ps_or_hierarchical_sequence_identifier
	: package_scope? sequence_identifier
	| hierarchical_sequence_identifier
	;

ps_or_hierarchical_tf_identifier
	: package_scope? tf_identifier
	| hierarchical_tf_identifier
	;

ps_or_hierarchical_net_identifier
	: package_scope? net_identifier
	| hierarchical_net_identifier
	;

ps_or_hierarchical_property_identifier
	: package_scope? property_identifier
	| hierarchical_property_identifier
	;

ps_parameter_identifier
	: (package_scope | class_scope)? parameter_identifier
	| (generate_block_identifier (LSQUARE constant_expression RSQUARE)? DOT )* parameter_identifier
	;

ps_type_identifier
	: (KW_LOCAL COLON2 | package_scope)? type_identifier
	;

attribute_instances
	: attribute_instance*
	;

attribute_instance
	: LPAREN MUL attr_spec ( COMMA attr_spec )* MUL RPAREN
	;

attr_spec
	: attr_name EQ constant_expression
	| attr_name
	;

attr_name
	: identifier
	;