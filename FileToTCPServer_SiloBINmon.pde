import processing.net.*;
import java.lang.RuntimeException;
import java.util.Arrays;
import java.io.FilenameFilter;

ArrayList<FileToTCPServer> FileToTCPServer_list = new ArrayList<FileToTCPServer>();

class FileToTCPServer {
  String server_ip;
  int server_port;
  String data_directory;
  String data_file_prefix;
  Server tcp_server_handle;
  String[] data_file_list;
  int data_file_list_count;
  int data_file_list_index;
  byte[] data_load_buf;
  int data_write_index;
  int data_write_length;

  FileToTCPServer(PApplet parent, String server_ip, int server_port, String data_directory, String data_file_prefix) {
    this.server_ip = server_ip;
    this.server_port = server_port;
    this.data_directory = data_directory;
    if (data_file_prefix == null || data_file_prefix == "") {
      this.data_file_prefix = "All";
    }
    else {
      this.data_file_prefix = data_file_prefix;
    }

    if (server_ip.charAt(0) == '#') {
      tcp_server_handle = null;
    }
    else if (server_ip == null || server_ip == "" || server_ip.equals("0.0.0.0")) {
      try {
        tcp_server_handle = new Server(parent, server_port);  // Start a simple server on a port
      }
      catch (RuntimeException e) {
        tcp_server_handle = null;
      }
    }
    else {
      try {
        tcp_server_handle = new Server(parent, server_port, server_ip);  // Start a simple server on a port
      }
      catch (RuntimeException e) {
        tcp_server_handle = null;
      }
    }

    if (tcp_server_handle == null) {
      return;
    }

    File data_directory_handle;

    data_directory_handle = new File(data_directory);

    if (!data_directory_handle.isAbsolute()) {
      data_directory_handle = new File(sketchPath() + "\\" + data_directory);
    }

    if (!data_directory_handle.isDirectory()) {
      return;
    }

    if (data_file_prefix == null || data_file_prefix == "") {
      data_file_list = data_directory_handle.list();
    }
    else {
      final String filename_prefix = data_file_prefix;
      data_file_list =
        data_directory_handle.list(
          new FilenameFilter() {
            @ Override final boolean accept(File dir, String name) {
              //println("name=" + name);
              return
                name.length() > filename_prefix.length()
                &&
                name.substring(0, filename_prefix.length()).equals(filename_prefix)
                &&
                name.toLowerCase().endsWith(".dat");
            }
          }
        );
    }

    if (data_file_list != null && data_file_list.length > 0) {
      Arrays.sort(data_file_list);
    }

    data_file_list_count = data_file_list.length;
    data_file_list_index = 0;
    println("data_file_list_count=" + data_file_list_count);
    //for (String file_name:data_file_list) {
    //  println("file_name=" + file_name);
    //}
  }

  void write_file_2_tcp_init(int length) {
    if (tcp_server_handle == null) return;
    if (data_file_list_count == 0) return;

    data_load_buf = loadBytes(data_directory+"\\"+data_file_list[data_file_list_index]);

    data_write_index = 0;
    data_write_length = length;

    data_file_list_index ++;
    if (data_file_list_index >= data_file_list_count)
      data_file_list_index = 0;
  }

  void write_file_2_tcp_continue() {
    if (tcp_server_handle == null) return;
    if (data_file_list_count == 0) return;

    if (data_load_buf == null) return;
    if (data_write_index >= data_load_buf.length) return;

    byte[] data_write_buf;

    data_write_buf = Arrays.copyOfRange(data_load_buf, data_write_index, ((data_load_buf.length - data_write_index) > data_write_length)?(data_write_index + data_write_length):data_load_buf.length);
    tcp_server_handle.write(data_write_buf);

    data_write_index += data_write_length;
    if (data_write_index >= data_load_buf.length) {
      data_write_index = data_load_buf.length;
    }
  }

  void write(byte[] data_buf) {
    if (tcp_server_handle == null) return;
    tcp_server_handle.write(data_buf);
  }

}

final static int FRAME_RATE = 5;
final static int BITS_PER_SECOND = 115200;
final static int BITS_TO_BYTES = 12;

void setup() {
  size(640, 300);
  background(250);
  fill(0);
  stroke(0);
  textAlign(LEFT, TOP);

  frameRate(FRAME_RATE); // Slow it down a little

  Table table;

  // Load lines file(CSV type) into a Table object
  // "header" option indicates the file has a header row
  table = loadTable(sketchPath() + "\\config.csv", "header");
  // Check loadTable ok.
  if(table != null) {
    for (TableRow variable:table.rows()) {
      String server_ip = variable.getString("Server_IP");
      int server_port = variable.getInt("Server_Port");

      println("Server_IP=" + server_ip);
      println("Server_Port=" + server_port);
      println("Data_Directory=" + variable.getString("Data_Directory"));
      println("Data_File_Prefix=" + variable.getString("Data_File_Prefix"));

      FileToTCPServer tcp_server =
        new FileToTCPServer(
          this,
          server_ip,
          server_port,
          variable.getString("Data_Directory"),
          variable.getString("Data_File_Prefix"));

      FileToTCPServer_list.add(tcp_server);
    }
  }

  //s = new Server(this, 7001, "192.168.0.71");  // Start a simple server on a port
}

void draw() {
  background(250);

  ArrayList<String> strings = new ArrayList<String>();

  for(FileToTCPServer ftts:FileToTCPServer_list) {
    String string;
    string = ftts.server_ip + ":" + ftts.server_port + " " + ftts.data_directory + " " + ftts.data_file_prefix + " ";
    if (ftts.tcp_server_handle != null) {
      string += "O " + ftts.data_file_list_count + " ";
      if (ftts.data_file_list_count == 0) {
        string += "No files ";
      }
      if (ftts.tcp_server_handle.clientCount > 0) {
        string += ftts.tcp_server_handle.clientCount + " ";
        if (ftts.data_file_list_count != 0) {
          string += ftts.data_file_list_index + " " + ftts.data_file_list[ftts.data_file_list_index];
        }
      }
      else
      {
        string += "No clients";
      }
    }
    else {
      string += "X";
    }
    strings.add(string);

    if (ftts.tcp_server_handle != null) {
      if (ftts.tcp_server_handle.clientCount > 0) {
        if (ftts.data_file_list_count != 0) {
          // Receive data from client
          Client client;
          client = ftts.tcp_server_handle.available();
          if (client != null) {
            byte[] input;

            input = client.readBytes();
            //input = input.substring(0, input.indexOf("\n"));  // Only up to the newline
            
            String cmd_prefix = new String(input, 0, 4);
            if (cmd_prefix.equals("GSCN")) {
              ftts.write_file_2_tcp_init(BITS_PER_SECOND/BITS_TO_BYTES/FRAME_RATE);
            }
            else {
              ftts.write(input);
            }
          }

          ftts.write_file_2_tcp_continue();
        }
      }
      else
      {
        ftts.data_file_list_index = 0;
      }
    }
  }

  int i = 0;
  for (String string:strings)
  {
    text(string, 5, i * 15);
    i ++;
  }

}
