# This file is part of CSVql.
#
# CSVql is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# CSVql is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with CSVql.  If not, see <http://www.gnu.org/licenses/>.

# Package: CSVql
# Provides methods for working with CSV files in a manner convenient for the
# CSV utilities.
package CSVql;

use Carp;
use Data::Dumper;
use Text::CSV;

use strict;
use warnings;

# Method: new
# Creates a new object representing the annotated CSV file.
#
# Parameters:
#  $class - the name of the class
#  %params - parameters for the CSV parser. Available values are
#		input => an IO object, from which the data are read. The
#		    default value is STDIN.
#		delimiter => a single-byte character used as delimiter
#		    in the CSV files. If not specified, it is detected
#		    from the first line of the file.
#		quote_char => a single-byt character used for quoting.
#		    If not specified, it is detected from the first line
#		    of the file.
#
sub new {
    my ($class, %params) = @_;
    $class = ref $class || $class;

    # Create the CSVql object
    my $self = {};
    bless $self, $class;

    # Use the specified input or STDIN 
    $$self{input} = $params{input} || \*STDIN;

    # Read the first line from the file, extract column names from it.
    my $heading = $self->_read_line();

    # Try to auto-detect parameters, if they were not specified
    my $delimiter = $params{delimiter} || _detect_delimiter($heading);
    my $quote_char = $params{quote_char} || _detect_quote_char($heading);

    # Create the CSV parser
    my $csv_params = {};
    $$csv_params{sep_char} = $delimiter if defined $delimiter;
    $$csv_params{quote_char} = $quote_char if defined $quote_char;
    $$self{csv} = Text::CSV->new($csv_params);

    # Read column names from the heading
    $self->_parse_heading($heading);

    return $self;
}

# Method: column_names
# Returns the names of the columns in the CSV file in the order, in which
# they appeared in the file.
#
# Returns:
# Reference to a list that contains the names of the columns in the order,
# in which they appeared in the file.
sub column_names {
    my ($self) = @_;
    return $$self{column_names};
}

# Method: _detect_delimiter
# Tries to detect the delimiter used in the CSV file. Measures the number of
# columns that it gets when splitting by tab and compares that to the number
# of columns created when splitting by comma. Uses the character that produces
# more columns.
#
# Parameters:
# $heading - a string that contains a sample line from the CSV file
# 
# Returns:
sub _detect_delimiter {
    my ($heading) = @_;

    my @by_comma = split ',', $heading;
    my @by_tab = split "\t", $heading;

    return ',' if @by_comma > @by_tab;
    return "\t";
}

# Method: _detect_quote_char
# Detects the quotation character from a line read from the file.
sub _detect_quote_char {
    my ($heading) = @_;

#TODO: do something with the file...
    return '"';
}

sub format {
    my ($self, @fields) = @_;

    my $csv = $$self{csv};
    unless ($csv->combine(@fields)) {
	croak "Could not combine fields to a string";
    }

    return $csv->string();
}

# Method: _parse_heading
# Reads the names of the columns from the heading.
sub _parse_heading {
    my ($self, $heading) = @_;

    my $csv = $$self{csv};
    unless($csv->parse($heading)) {
	croak "Could not parse column names";
    }

    my @names = $csv->fields();

    $$self{column_names} = \@names;
    $$self{column_count} = scalar(@names);

    my $columns_by_name = {};
    for(my $c = 0; $c < @names; $c++) {
	my $name = $names[$c];
	warn "Duplicate column name: $name" if exists $$columns_by_name{$name};
	$$columns_by_name{$name} = $c;
    }
    $$self{columns_by_name} = $columns_by_name;
}

# Method: fetch_line
# Reads and parses the next line from the input.
sub fetch_row {
    my ($self) = @_;

    my $fields = $self->_parse_line();
    return undef unless $fields;

    my $row = {};
    my $column_names = $$self{column_names};

    for(my $i = 0; $i < @$fields; $i++) {
	my $name = $$column_names[$i];
	$$row{$name} = $$fields[$i];
    }
    return $row;
}

# Method: is_column
# Checks that a column of the given name is present in the CSV file.
#
# Parameters:
#   $column - the name of the column
#
# Returns:
# A true value if $column is a name of a column in the CSV file.
sub is_column {
    my ($self, $column) = @_;

    return exists $$self{columns_by_name}{$column};
}

# Method: _parse_line
# Reads one line from the input and parses it to a list of values.
sub _parse_line {
    my ($self) = @_;

    my $csv = $$self{csv};
    my $line = $self->_read_line();
    return undef unless $line;

    unless ($csv->parse($line)) {
	croak "Could not parse the input: $line";
    }

    my @fields = $csv->fields();
    my $field_count = @fields;
    my $expected_count = $$self{column_count};
    unless ($expected_count == $field_count) {
	warn "Expected $expected_count fields, found $field_count";
    }

    return \@fields;
}

# Method: _read_line
# Reads the next data line from the CSV file. Skips empty lines and
# comments. Returns the line as a string, or undef if there are no
# more data in the CSV file.
#
# Returns:
# The line read from the input. Returns *undef* upon EOF.
sub _read_line {
    my ($self) = @_;

    my $input = $$self{input};

    my $line = <$input>;
    while(defined $line) {
	chomp $line;
	# Skip empty lines, skip lines starting with hash mark
	# or with semicolon (these are treated as comments)
	last unless ($line =~ /^\s*$/ or $line =~ /^\s*[#;]/);

	$line = <$input>;
    }
    return $line;
}

1;

__END__
