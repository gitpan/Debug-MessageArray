package Debug::MessageArray;
use strict;
use Debug::ShowStuff ':all';
use String::Util ':all';
use Data::Default ':all';
use Carp qw[croak confess];
use Digest::MD5 'md5_base64';

# version
use vars '$VERSION';
$VERSION = '0.11';

# GLOBALS
our @errors;
our @warnings;
our @notes;
our %msgs = ('errors' => \@errors, 'warnings' => \@warnings, 'notes' => \@notes);
our $die_on_error = 0;

=head1 NAME

Debug::MessageArray -- A module for setting and returning messages such as
errors, warnings, and notes.

=head1 SYNOPSIS

 use Debug::MessageArray ':all';

 # clear all messages
 clear_global_messages();

 # add an error to the global array
 add_error('Filehandle not open');

 # show errors
 output_errors_html();

 # many other functions and features

=head1 DESCRIPTION

This module was created with the idea that a function might produce any
number of errors or other messages, not just one.  This function uses
a set of global arrays to store messages from functions.

There are three types of messages.  Errors are for when something went wrong
and the function call didn't work out.  Warnings are for when something
suspicious happened that the programmer or user needs to know about, but there
wasn't actually an error.  Notes are for when nothing at all is wrong, but
the programmer or user ought to know something.

The word "message" is used to indicate a generic object that could be an
error, warning, or note.

The basic idea is that your code adds a message at any point where it needs
to be added.  Later, when appropriate, your code displays those messages.

For example, the following code adds an error message to the global array:

 add_error("Could not open file handle");

Later, at some other point far removed from where the error happened, you
can display any errors:

 show_errors();

To clear messages, call C<clear_global_messages()>:

 clear_global_messages();

That's the basic idea.  Everything else is a refinement.  There are a lot
of refinements, so read on for details with each function.

=head1 SITE OBJECT

C<Debug::MessageArray> provides a system by which your code can add messages
using IDs instead of text.  This can be useful for situations where the
messages might be output in different languages or you want to be able to
change the text of a message in a single place but the message is created in
many places in your code.

This objective is achieved with the use of a "site" object that you provide.
Your site object simply has to provide three methods: C<$site->get_message_text()>
and C<$site->get_message_html()>, and C<process_message_tag()>.  Each of those
methods will get a single argument, the ID of a message.  Given that ID, the
site object should be able to return either text or HTML for the given ID.

For example, consider the following Perl class.  This class allows messages to
be displayed in either English or Spanish:

 package SiteClass;
 use strict;
 use Debug::ShowStuff ':all';
 use Carp 'croak';

 # hash of message by language
 my $messages = {};
 $messages->{'en'} = {};
 $messages->{'es'} = {};

 # English: cannot open file handle
 $messages->{'en'}->{'no-new-file-handle'} = {
      text => 'Cannot open *new* file handle',
      html => 'Cannot open <em>new</em> file handle',
 };

 # English: no permission
 $messages->{'en'}->{'no-permission'} = {
      text => 'Do not have permission',
 };

 # Spanish: cannot open file handle
 $messages->{'es'}->{'no-new-file-handle'} = {
     text => 'No se puede abrir el archivo de *nuevo* mango',
      html => 'No se puede abrir el archivo de <em>nuevo</em> mango',
 };

 # Spanish: no permission
 $messages->{'es'}->{'no-permission'} = {
      text => 'No tiene permiso',
 };

 sub new {
      my ($class, $lang) = @_;

     # must have language
     defined($lang) or croak 'must have language';

      # return blessed object
      return bless {lang=>$lang}, $class;
 }

 sub get_message_text {
      my ($site, $msg) = @_;
      my $definition = $messages->{$site->{'lang'}}->{$msg->{'id'}};

      if (! $definition)
           { croak qq|do not have message id "$msg->{'id'}"| }

      return $definition->{'text'};
 }

 sub get_message_html {
      my ($site, $msg) = @_;
      my ($definition, $str);
      $definition = $messages->{$site->{'lang'}}->{$msg->{'id'}};

      if (! $definition)
           { croak qq|do not have message id "$msg->{'id'}"| }

      # get HTML if available
      if (defined $definition->{'html'}) {
           $str = $definition->{'html'};
      }

      # use text if available
      else {
           $str = $definition->{'text'};

           $str =~ s|\&|&amp;|g;
           $str =~ s|\"|&quot;|g;
           $str =~ s|\<|&lt;|g;
           $str =~ s|\>|&gt;|g;
      }

      # return
      return $str;
 }

The following script uses C<DEBUG::MessageArray> and a SiteClass object
to display the same set of messages in Engligh and in Spanish:

 #!/usr/bin/perl -w
 use strict;
 use Debug::MessageArray ':all';
 require './SiteClass.pm';

 # variables
 my ($site);

 # instantiate site object, setting it to English
 $site = SiteClass->new('en');

 # create some errors
 add_error(id=>'no-new-file-handle');
 add_error(id=>'no-permission');

 # show errors in English
 print "show errors in English\n";
 show_errors(site=>$site);

 # Change site object to Spanish, then show errors in Enligh
 print "show errors in Spanish\n";
 $site->{'lang'} = 'es';
 show_errors(site=>$site);

This code will produce the following output:

 show errors in English
 * Cannot open *new* file handle
 * Do not have permission
 show errors in Spanish
 * No se puede abrir el archivo de *nuevo* mango
 * No tiene permiso

B<method:> process_message_tag()

C<process_message_tag()> provides the ability to return a string based on
a message tag.  C<process_message_tag()> gets three parameters: the message
site object, the message object, the tag that was sent (including tag name)
and parameters, and the type of media being output (text or HTML).

C<process_message_tag()> is not required.  It will only be called if the
site object has such a method.

=head1 FUNCTIONS

=cut


#------------------------------------------------------------------------------
# export
#
use base 'Exporter';
use vars qw[@EXPORT_OK %EXPORT_TAGS];

# functions
push @EXPORT_OK, qw[
	errors warnings notes messages
	
	fatal_on_error
	
	clear_global_messages
	
	add_error add_warning add_note
	add_errors add_warnings add_notes
	add_message add_dbi_err
	
	any_errors any_warnings any_notes
	
	output_errors_html output_warnings_html output_notes_html
	output_errors_text output_warnings_text output_notes_text
	die_errors die_on_error
	
	show_errors
	
	xml_to_messages
	
	get_message_string
	
	message_output_id
];

%EXPORT_TAGS = ('all' => [@EXPORT_OK]);
#
# export
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# clear_global_messages
#

=head2 clear_global_messages()

Clears the global messages arrays.

=cut

sub clear_global_messages {
	@errors = ();
	@warnings = ();
	@notes = ();
	
	# return success
	return 1;
}
#
# clear_global_messages
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# get messages
#

=head2 errors, warnings, messages

Returns one of the global arrays of messages.

=cut

sub errors   { return @errors }
sub warnings { return @warnings }
sub notes    { return @notes }

sub messages {
	my ($type) = @_;
	
	if ($type eq 'errors') { return @errors }
	if ($type eq 'warnings') { return @warnings }
	if ($type eq 'notes') { return @notes }
	
	croak "do not have message type $type";
}

#
# get messages
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------------------
# add_error, add_warning, add_note
# adds errors, warnings, notes to their respective arrays
#

=head2 add_error, add_warning, add_note

C<add_error()>, C<add_message()> and C<add_note()> add a single message to
their respective global arrays.

B<NOTE>: We'll use C<add_error()> in these examples.  C<add_message()> and
C<add_note()> work exactly the same way.

In its simplest use, call C<add_error()> with a single text parameter:

 add_error('Unable to open file handle');

C<add_error()> returns a hash reference containing the text of the message.
This hashref is the object that is stored in the global array.  The message
above would look like this:

 {
    text => 'Unable to open file handle',
 }

You can also pass in the parameters as a hash.  the C<text> element provides
the text for the error.  For example, the following code accomplishes exactly
the same thing as the example above:

 add_error(text => 'Unable to open file handle');

The following sections explain the various options for calling C<add_error()>.

B<option:> text

Provides the text for the message.  For example, this call adds an error
with some text:

 add_error(text => 'Unable to open file handle');

B<option:> html

Provides and HTML version of the message.  If you use the C<html> param
you should also always use the C<text> param for when the message isn't
displayed in a web environment.  For example, the following code adds
a message with a text and an HTML version:

 add_error(
    text => 'Unable to open *new* file handle',
    html => 'Unable to open <em>new<em> file handle',
 );

If an HTML version of the message isn't displayed, and the message should
be displayed in a web environment, then the text version is HTML-escaped and
displayed.

B<option:> id

The C<id> param can be used instead of C<text> and C<html> for situations
where your code can later provide text and/or HTML for a given id. See below
for an explanation of the site object see the "SITE OBJECT" documentation
above.

=cut

sub add_message {
	my $arr = shift;
	my ($msg);
	
	# if message array sent by name instead of object,
	# get object
	if (! ref $arr)
		{ $arr = $msgs{$arr} }
	
	# if single param sent, use as text
	if (@_ == 1) {
		if (ref $_[0])
			{ $msg = $_[0] }
		else
			{ $msg = {text=>$_[0]} }
	}
	
	else {
		$msg = {@_};
	}
	
	# add to global array
	push @$arr, $msg;
	
	# return message object
	return $msg;
}

sub add_messages {
	my ($arr, @raw) = @_;
	my (@rv);
	
 	foreach my $msg_raw (@raw) {
		if (ref $msg_raw) {
			push @$arr, $msg_raw;
			push @rv, $msg_raw;
		}
		
		else {
			my $msg = {text=>$msg_raw};
			push @$arr, $msg;
			push @rv, $msg;
		}
 	}
	
	return @rv;
}

sub add_error {
	my $msg = add_message(\@errors, @_);
	
	if ($die_on_error) {
		output_errors_text();
		confess 'errors';
	}
	
	return $msg;
}

sub add_errors {
	return add_messages(\@errors, @_);
}

sub add_warning {
	return add_message(\@warnings, @_);
}

sub add_warnings {
	return add_messages(\@warnings, @_);
}

sub add_note {
	add_message(\@notes, @_);
}

sub add_notes {
	add_messages(\@notes, @_);
}
#
# add_error, add_warning, add_note
#------------------------------------------------------------------------------------------



#------------------------------------------------------------------------------
# any_errors, any_warnings, any_notes
#

=head2 any_errors(), any_warnings(), any_notes()

Returns true if there are errors/warnings/notes, false otherwise.

=cut

sub any_errors {
	return scalar(@errors);
}

sub any_warnings {
	return scalar(@warnings);
}

sub any_notes {
	return scalar(@notes);
}
#
# has_errors, has_warnings, has_notes
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# process_tags
#
# Private subroutine: Substitutes in the value of parameters for
# tags.
#
sub process_tags {
	my ($msg, $msg_str, $type, %opts) = @_;
	my (@elements, $rv);
	
	# parse
	@elements = split m|(\[:.*?:\])|s, $msg_str;
	
	# subsitute elements
	foreach my $el (@elements) {
		# if tag
		if ($el =~ s|^\[:\s*(.*)\s*:\]$|$1|s) {
			$el = process_tag($msg, $el, $type, %opts);
		}
	}
	
	# return
	return join('', @elements);
}
#
# process_tags
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# process_tag
#
# Private subroutine: Substitutes in the value of a single parameter for
# a tag.
#
sub process_tag {
	my ($msg, $tag_str, $type, %opts) = @_;
	my ($tag_name, $atts_raw, %atts, $rv, $site);
	$site = $opts{'site'} || $msg->{'site'};
	$rv = '';
	
	# get tag name
	($tag_name, $atts_raw) = split(m|\s+|s, $tag_str, 2);
	$tag_name = lc($tag_name);
	
	# parse up tags
	%atts = get_atts($atts_raw);
	
	# sub
	if ($tag_name eq 'sub') {
		$rv = $msg->{'params'}->{$atts{'param'}};
		
		if (! defined $rv)
			{ print STDERR "do not have param $atts{'param'}\n" }
		
		if ($opts{'html'})
			{ $rv = htmlesc($rv) }
	}
	
	# other tags
	elsif ($site && $site->can('process_message_tag')) {
		my $tag = {};
		$tag->{'name'} = $tag_name;
		$tag->{'atts'} = \%atts;
		
		$rv = $site->process_message_tag($msg, $tag, $type);
	}
	
	# 	elsif ($tag_name eq 'site-title') {
	# 		if (! $site)
	# 			{ croak 'do not have message site object' }
	# 		
	# 		$rv = $site->title();
	# 		
	# 		if ($opts{'html'})
	# 			{ $rv = htmlesc($rv) }
	# 	}
	
	# return
	return $rv;
}
#
# process_tag
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# get_atts
#
# Private method: parses a tag and returns the attributes in the tag.
#
sub get_atts {
	my ($raw) = @_;
	my (%rv, @blocks);
	
	# early exit: nothing to parse
	defined($raw) or return %rv;
	
	# split into blocks
	@blocks = split m/(\S+\s*=\s*(?:(?:\".*?\"))|\S+)/s, $raw;
	@blocks = grep {hascontent($_)} @blocks;
	
	# build hash of atts
	foreach my $block (@blocks) {
		my ($n, $v) = split(m|\s*=\s*|s, $block, 2);
		$n = lc($n);
		$v = trim($v);
		$v = unquote($v);
		$rv{$n} = $v;
	}
	
	# return
	return %rv;
}
#
# get_atts
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# errors_text, errors_text, errors_text
#

=head2 errors_text(), errors_text(), errors_text()

Prints to STDOUT the errors/warnings/notes as text.

C<option:> site

If the C<site> parameter is sent, then each message must have an 'id'
element.  See the "SITE OBJECT" section above for an explanation of how
site objects and message IDs work.  If any message object has just an
'id' property, but no site object is sent then an error will occur.

=cut

sub show_errors {return output_errors_text(@_)}

sub output_errors_text {
	return output_messages_text(
		\@errors,
		singular=>'Error',
		plural=>'Errors',
		@_,
	);
}

sub output_warnings_text {
	return output_messages_text(
		\@warnings,
		singular=>'Warning',
		plural=>'Warnings',
		@_,
	);
}

sub output_notes_text {
	return output_messages_text(
		\@notes,
		singular=>'Note',
		plural=>'Notes',
		h2=>0,
		@_,
	);
}

sub output_messages_text {
	my ($arr, %opts) = @_;
	
	# if nothing in the list, we're done
	unless (@$arr)
		{ return '' }
	
	# variables
	my ($multi, %err_so_far, @errors_use, $singular, $plural);
	$singular = $opts{'singular'};
	$plural = $opts{'plural'};
	
	# build unique array of errors
	foreach my $err (@$arr) {
		my ($site, $err_use, $err_tagged);
		
		# get site if it exists
		$site = $opts{'site'} || $err->{'site'};
		
		if ( $site && $err->{'id'} )
			{ $err_tagged = $site->get_message_text($err) }
		elsif (defined $err->{'text'})
			{ $err_tagged = $err->{'text'} }
		elsif (defined $err->{'html'})
			{ $err_tagged = textesc($err->{'html'}) }
		
		# if there is neither text nor text error, that's an error
		else {
			showhash $err;
			
			if ($err->{'params'})
				{ showhash $err->{'params'}, title=>'params' }
			
			croak '[2] Error object has neither text nor html property';
		}
		
		# substitions
		$err_use = process_tags($err, $err_tagged, 'text', %opts);
		
		if (! $err_so_far{$err_use}) {
			push @errors_use, $err_use;
			$err_so_far{$err_use} = 1;
		}
	}
	
	# note if there is more than one error
	$multi = @errors_use > 1;
	
	# output messages
	# $multi and print '* ';
	print '* ';
	print join("\n* ", @errors_use);
	print "\n";
}
#
# errors_text, warnings_text, notes_text
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# errors_html, warnings_html, notes_html
#

=head2 output_errors_html(), output_warnings_html(), output_notes_html()

Prints to STDOUT the errors/warnings/notes as HTML.  For each message, if
Works like errors_html/warnings_html/notes_html except outputs HTML.
If there is an 'html' property then that is output.  Otherwise the text
property is HTML-escaped and output.

=cut

sub output_errors_html {
	return output_messages_html(
		\@errors,
		singular=>'Error',
		plural=>'Errors',
		type => 'errors',
		@_,
	);
}

sub output_warnings_html {
	return output_messages_html(
		\@warnings,
		singular=>'Warning',
		plural=>'Warnings',
		type => 'warnings',
		@_,
	);
}

sub output_notes_html {
	return output_messages_html(
		\@notes,
		singular => 'Note',
		plural   => 'Notes',
		h2       => 0,
		type => 'notes',
		@_,
	);
}

sub output_messages_html {
	my ($arr, %opts) = @_;
	my ($prefix);
	
	# prefix
	if (hascontent $opts{'prefix'})
		{ $prefix = $opts{'prefix'} . '~' }
	else
		{ $prefix = '' }
	
	# if nothing in the list, we're done
	unless (@$arr)
		{ return '' }
	
	# variables
	my ($multi, %err_so_far, $lis, $singular, $plural, @classes);
	$singular = $opts{'singular'};
	$plural = $opts{'plural'};
	$lis = '';
	
	# build unique array of messages
	foreach my $err (@$arr) {
		my ($err_tagged, $err_use, $site, $id);
		
		$site = $err->{'site'} || $opts{'site'};
		
		# get text or HTML
		if ( $site && $err->{'id'} )
			{ $err_tagged = $site->get_message_html($err) }
		elsif (defined $err->{'html'} )
			{ $err_tagged = $err->{'html'}  }
		elsif (defined $err->{'text'})
			{ $err_tagged = htmlesc($err->{'text'}) }
		
		# if there is neither text nor
		#  HTML error, that's an error
		else {
			showhash $err;
			croak '[1] Error object has neither text nor HTML property';
		}
		
		# substitions
		$err_use = process_tags($err, $err_tagged, 'html', %opts);
		
		# output if not already done so
		if (! $err_so_far{$err_use}) {
			$lis .= '<li';
			
			if (defined $err->{'id'}) {
				$id = $prefix . message_output_id($err);
				$lis .= qq| id="$id"|;
			}
			
			$lis .= '>';
			
			# show message id if opted to do so
			if (defined($err->{'id'}) && $opts{'show_msg_ids'}) {
				$lis .= '[ ' . $id . ' ] ';
			}
			
			$lis .= qq|$err_use</li>|;
			$err_so_far{$err_use} = 1;
		}
	}
	
	# note if there is more than one error
	$multi = keys(%err_so_far) > 1;
	
	# build classes
	push @classes, 'messages';
	push @classes, "messages-$opts{'type'}";
	
	# if single, add single class
	if (! $multi)
		{ push @classes, 'messages-single' }
	
	
	# open section for errors
	print '<div';
	
	# add classes
	print ' class="', join(' ', @classes), '"';
	
	if ($opts{'div_atts'}) {
		while (my($k,$v) = each(%{$opts{'div_atts'}}))
			{ print qq| $k="$v"| }
	}
	
	print '>';
	
	# <h2>
	if (default $opts{'h2'}, 1) {
		print '<h2>';
		
		if ($multi)
			{ print $plural }
		else
			{ print $singular }
		
		print "</h2>\n";
	}
	
	# open <ul> element
	print '<ul';
	
	# optional attributes for <ul>
	if ($opts{'ul_atts'}) {
		while (my($k,$v) = each(%{$opts{'ul_atts'}}))
			{ print qq| $k="$v"| }
	}
	
	# finish opening <ul> element
	print '>';
	
	# output list of messages
	# NOTE: The HTML output here intentionally has no whitespace
	# between the tags.  That is so that automated testers can
	# tell how many elements are in the errors <ul> element.
	print $lis, qq|</ul>\n</div>\n|;
}
#
# errors_html, warnings_html, notes_html
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# die_on_error
#
sub die_on_error {
	if (@_)
		{ $die_on_error = $_[0] }
	
	return $die_on_error;
}
#
# die_on_error
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# die_errors
#
sub die_errors {
	my (%opts) = @_;
	
	if (! any_errors())
		{ return 1 }
	
	output_errors_text(%opts);
	croak 'errors';
}
#
# die_errors
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# xml_to_messages
#

=head1 xml_to_messages($raw_xml)

Parses a standed MessageArray XML document, add messages to appropriate array.

=cut

sub xml_to_messages {
	my ($raw, %opts) = @_;
	my ($parser, $tree, @msg_els);
	
	# loading XML parsing library
	require XML::Parser;
	
	# strip stuff from around xml if called upon to do so
	if ($opts{'strip'}) {
		$raw =~ s|^.*?<|<|s;
		$raw =~ s|^(.*</messages>).*|$1|s;
	}
	
	# get list of messages
	$parser = XML::Parser->new(Style => 'Objects');
	$tree = $parser->parse($raw);
	$tree = $tree->[0];
	@msg_els = get_class($tree, 'message');
	
	# loop through messages adding to appropriate array
	foreach my $msg (@msg_els) {
		my (@property_els);
		
		# must be key for existing message array
		unless ( UNIVERSAL::isa $msgs{$msg->{'list'}}, 'ARRAY' )
			{ croak "non-existent message array: $msg->{'list'}" }
		
		# add to appropriate array
		push @{$msgs{$msg->{'list'}}}, $msg;
		
		# get properties
		@property_els = get_class($msg, 'property');;
		
		# loop through properties of message
		foreach my $property (@property_els) {
			my ($value);
			
			# if no "value" element then use contents
			if (exists $property->{'value'}) {
				$value = $property->{'value'};
			}
			
			else {
				$value = $property->{'Kids'}->[0]->{'Text'};
			}
			
			$msg->{$property->{'key'}} = $value;
		}
	}
	
	# return success
	return 1;
}

# get specific class of Kids
sub get_class {
	my ($el, $class) = @_;
	my (@rv);
	
	# get just the class
	@rv = @{$el->{'Kids'}};
	@rv = grep {UNIVERSAL::isa $_, "Debug::MessageArray::${class}"} @rv;
	
	# return
	return @rv;
}

#
# xml_to_messages
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# add_dbi_err
#

=head2 add_dbi_err()

If there is a DBI error, adds it to the errors array and returns
true (meaning there was an error).  Else returns false.

Takes no params.  

=cut

sub add_dbi_err {
	if ($DBI::err) {
		add_error($DBI::errstr);
		return 1;
	}
	
	return 0;
}
#
# add_dbi_err
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# get_message_string
#
sub get_message_string {
	my ($msg, $type, %opts) = @_;
	my ($raw, $site);
	
	# check params
	$msg or croak 'no $msg object';
	
	# get site objects if it exists
	$site = $opts{'site'} || $msg->{'site'};
	
	# if message has an ID and a site object was sent
	if ($site && defined($msg->{'id'})) {
		$raw = $site->get_raw_message_string($msg->{'id'}, $type, %opts);
	}
	
	# if type is text
	elsif ($type eq 'text') {
		if (defined $msg->{'text'})
			{ $raw = $msg->{'text'} }
		else
			{ return '[unknown message type 1]' }
	}
	
	# want html
	elsif ($type eq 'html') {
		if (defined $msg->{'html'})
			{ $raw = $msg->{'html'} }
		elsif (defined $msg->{'text'})
			{ $raw = htmlesc($msg->{'text'}) }
		else
			{ return '[unknown message type 2]' }
	}
	
	# else unknown type
	else {
		return '[unknown message type 3]';
	}
	
	# process tags
	return process_tags($msg, $raw, $type, %opts);
}
#
# get_message_string
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# message_output_id
#
sub message_output_id {
	my ($id, $params, $rv);
	
	# if first argument is a reference, use that
	if (ref $_[0]) {
		$id = $_[0]->{'id'};
		$params = $_[0]->{'params'} || {};
	}
	
	# else first argument is string, rest are params
	else {
		$id = shift(@_);
		$params = {@_};
	}
	
	# begin return string
	$rv = $id;
	
	# add params if any
	if (%$params) {
		my (@tokens);
		$rv .= '~';
		
		foreach my $key (sort keys %$params) {
			my $token = $key;
			
			if (defined $params->{$key})
				{ $token .= '=' . $params->{$key} }
			
			push @tokens, $token;
		}
		
		$rv .= md5_base64(join "\t", @tokens);
	}
	
	# return
	return $rv;
}
#
# message_output_id
#------------------------------------------------------------------------------



# return true
1;

__END__

=head1 TERMS AND CONDITIONS

Copyright (c) 2010 by Miko O'Sullivan.  All rights reserved.  This program is 
free software; you can redistribute it and/or modify it under the same terms 
as Perl itself. This software comes with B<NO WARRANTY> of any kind.

=head1 AUTHORS

Miko O'Sullivan
F<miko@idocs.com>

=head1 VERSION

=over

=item Version 0.10    November 7, 2010

Initial release.

=item Version 0.11    November 8, 2010

Fixing bug in Makefile.  Did not list XML::Parser as a prerequisite.

=back


=cut
