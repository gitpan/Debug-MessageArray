#!/usr/bin/perl -w
use strict;
# use Debug::ShowStuff ':all';
use Debug::MessageArray ':all';
use Test;
BEGIN { plan tests => 9 };


#------------------------------------------------------------------------------
# test clear_global_messages
#

# add a message
add_error('my error');

# there should now be an error
check_ok (
	scalar(any_errors()),
	'should be an error after adding an error message',
);

# clear messages
clear_global_messages();

# there should not be an error
check_ok (
	(! any_errors()),
	'should not be an error after calling clear_global_messages()',
);

#
# test clear_global_messages
#------------------------------------------------------------------------------



#------------------------------------------------------------------------------
# test add_error()
#
do {
	my ($msg, $text);
	
	# text of message
	$text = 'my error';
	
	# clear messages
	clear_global_messages();
	
	# add an error
	$msg = add_error($text);
	
	# should be exactly one error
	check_ok (
		$msg,
		'did not get back message object'
	);
	
	# should be exactly one error
	check_ok (
		(errors() == 1),
		'error: should be exactly one error',
	);
	
	# check text in message object
	check_ok (
		($msg->{'text'} eq $text),
		'message text did not match input text'
	);
};
#
# test add_error()
#------------------------------------------------------------------------------



#------------------------------------------------------------------------------
# test xml_to_messages()
#
do {
my ($raw, $doc, @errors);

# clear messages
clear_global_messages();

# raw message
$raw = <<'(XML)';
<messages>
	<message list="errors">
		<property key="text" value="Error in attribute"/>
	</message>
	
	<message list="errors">
		<property key="text">Error in contents</property>
	</message>
</messages>
(XML)


# parse
xml_to_messages($raw);
@errors = errors();

# check error value in first message
check_ok (
	($errors[0]->{'text'} eq 'Error in attribute'),
	'got incorrect error string in first message'
);

# check error value in first message
check_ok (
	($errors[1]->{'text'} eq 'Error in contents'),
	'got incorrect error string in second message'
);

# raw message
$raw = <<'(XML)';
stuff before
<messages>
	<message list="errors">
		<property key="text" value="Error in attribute"/>
	</message>
	
	<message list="errors">
		<property key="text">Error in contents</property>
	</message>
</messages>
stuff after
(XML)

# parse
xml_to_messages($raw, strip=>1);
@errors = errors();

# check error value in first message
check_ok (
	($errors[0]->{'text'} eq 'Error in attribute'),
	'got incorrect error string in first message',
);

# check error value in first message
check_ok (
	($errors[0]->{'text'} eq 'Error in attribute'),
	'got incorrect error string in second message',
);

};
#
# test xml_to_messages()
#------------------------------------------------------------------------------


# done
print STDERR "done\n";


###############################################################################


#------------------------------------------------------------------------------
# check_ok
#
sub check_ok {
	my ($bool, $text) = @_;
	
	# if sucess
	if ($bool) {
		ok(1);
	}
	else {
		print STDERR "ERROR: $text\n";
		ok(0);
	}
}
#
# check_ok
#------------------------------------------------------------------------------
