use Win32::SerialPort; 

# подпрограмма бинарного преобразования беззнакового Int-16 в Int-16 со знаком --------------------
sub uint16_int16
{
  my $v = shift;
  return ($v & 0x8000) ? -((~$v & 0xffff) + 1) : $v; 
}
#--------------------------------------------------------------------------------------------------

@COMNumb=('1','2','3','4','5','6','7','8','9'); # разрешённые номера для СОМ-порта
# проверка правильности введённого номера порта (не оптимально, но пойдёт)
$match=0;
while ($match==0)
{
	print "Enter COM-port number: ";
	$PortNumb=<STDIN>;
	chop $PortNumb;
	if ($PortNumb eq 'd')
	{
		print "This will clear memory! Ctrl+C to interrupt and quit.\n";
		<>;
		print "Enter COM-port number: ";
		$PortNumb=<STDIN>;
		chop $PortNumb;
		$Port="COM".$PortNumb;
		# проверяем, что порт может быть открыт----------------------------------------------------
		if (eval
			{
				my $port = Win32::SerialPort->new($Port);
				$port->baudrate(9600);
			}
		    ) 
		{
			print($Port);
		}
		else
		{
			print "Can't open $Port. Press Enter to quit.\n";
			<>;		# для exe-версии
			exit 0; # останавливаем программу	
		}
		#------------------------------------------------------------------------------------------		
		my $port = Win32::SerialPort->new($Port) || die "Can't open $Port.\n";
		$port->baudrate(9600); # Configure this to match your device
		$port->databits(8);
		$port->parity("none");
		$port->stopbits(1);
		$port->write_settings || undef $port;
		$port->write('d');
		print " is opened.\n";		
		print "Wait while red light blinking...\n";
		<>;
		$port->close; # закрываем СОМ-порт		
		exit 0; 	  # останавливаем программу
	}
	foreach $item (@COMNumb)
	{
		if ($PortNumb==$item)
		{
			$match=1;
		}
	}
}
$Port="COM".$PortNumb;
# проверяем, что порт может быть открыт -----------------------------------------------------------
if (eval
	{
		my $port = Win32::SerialPort->new($Port);
		$port->baudrate(9600);
	}
	) 
{
	print($Port);
}
else
{
	print "Can't open $Port. Press Enter to quit.\n";
	<>;		# для exe-версии
	exit 0; # останавливаем программу	
}
#--------------------------------------------------------------------------------------------------
my $port = Win32::SerialPort->new($Port) || die "Can't open $Port: $^E.\n";
$port->baudrate(9600); # Configure this to match your device
$port->databits(8);
$port->parity("none");
$port->stopbits(1);
$port->write_settings || undef $port;
print " is opened, press Enter to read memory.\n";
<>;
$TotalBytesReceived=0;
# массив масок
@BitMask=(0b1000000000000000,
		  0b0100000000000000,	
          0b0010000000000000,
		  0b0001000000000000,
          0b0000100000000000,
		  0b0000010000000000,	
          0b0000001000000000,
		  0b0000000100000000,
          0b0000000010000000,
		  0b0000000001000000,	
          0b0000000000100000,
		  0b0000000000010000,
          0b0000000000001000,
		  0b0000000000000100,	
          0b0000000000000010,
		  0b0000000000000001);	

$port->write('r');

# открываем файл для записи
my $filename = 'out.txt';	
# проверяем, что файл не заблокирован -------------------------------------------------------------
if (eval ("open(my $fh, '>', $filename);"))
{
	print "'$filename' is OK.\n";
}
else
{
	print "Can't open '$filename'. Check if it's blocked. Press Enter to quit.\n";
	<>;		# для exe-версии
	exit 0; # останавливаем программу	
}		
#--------------------------------------------------------------------------------------------------
open(my $fh, '>', $filename) or die "Can't open '$filename'.\n";
$count8=0;
while ($TotalBytesReceived < 25856) # 25856
# while ($TotalBytesReceived < 25858) # 25858
{
	# исходное двухбайтное целое, обнулённое
	$TwoBytesInt=0b0000000000000000;
	($count_in, $string_in) = $port->read(1);
	if($count_in != 0)
	{	
		$bit_string =  unpack('B*',$string_in);
#		$bit_string =~ s/(....)(?=.)/${1}_/g;	# разделение блоков по 4 бита
		$bit_string =~ s/(....)(?=.)/${1}/g;	
		$TotalBytesReceived=$TotalBytesReceived+$count_in;
		# если байт нечётный, сохраняем его как старший
		if($TotalBytesReceived%2 != 0)
		{
			print "HB bits: $bit_string\n";		
			$HB=$bit_string;
		}
		# если байт чётный, обрабатываем оба байта
		else
		{
			print "LB bits: $bit_string\n";		
# 			превращаем строки в массивы символов
			@HByte=split(//, $HB);
			@LByte=split(//, $bit_string);
			
			for($i=0; $i<=7; $i++)
			{
				if($HByte[$i] eq '1')
				{
					$TwoBytesInt = $TwoBytesInt | $BitMask[$i];
				}
			}
			for($i=0; $i<=7; $i++)
			{
				if($LByte[$i] eq '1')
				{
					$TwoBytesInt = $TwoBytesInt | $BitMask[$i+8];
				}
			}
			print "Total bytes received: $TotalBytesReceived\n";
			$count8++;	# увеличиваем счётчик на 1			
			print "Final number: ";
			$FinNumb=uint16_int16($TwoBytesInt);
			print $FinNumb;
			print "\n";				
			printf ('%b',$TwoBytesInt);
			print "\n\n";
			print $fh $FinNumb;
			print $fh "\t";			
			if($count8==8)
			{
				print $fh "\n";
				$count8=0;
			}
		}
	}
    $port->lookclear; # needed to prevent blocking
}
$port->close; # закрываем СОМ-порт
close $fh;
print "Program finished, press Enter to quit.\n"; # Для exe-версии, чтобы окно сразу не закрывалось.
<>;