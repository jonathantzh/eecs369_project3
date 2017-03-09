/*
 * Copyright (c) 2006 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA,
 * 94704.  Attention:  Intel License Inquiry.
 */

/**
 * Oscilloscope demo application. Uses the demo sensor - change the
 * new DemoSensorC() instantiation if you want something else.
 *
 * See README.txt file in this directory for usage instructions.
 *
 * @author David Gay
 */
configuration OscilloscopeAppC { }
implementation
{
  components OscilloscopeC, MainC, ActiveMessageC as Radio, LedsC, SerialActiveMessageC as Serial,
    new TimerMilliC(), new DemoSensorC() as Sensor,
    new AMSenderC(AM_OSCILLOSCOPE), new AMReceiverC(AM_OSCILLOSCOPE);

  OscilloscopeC.Boot -> MainC;
  OscilloscopeC.RadioControl -> Radio;
  OscilloscopeC.AMSend -> AMSenderC;
  OscilloscopeC.OsReceive -> AMReceiverC;
  OscilloscopeC.Timer -> TimerMilliC;
  OscilloscopeC.Read -> Sensor;
  OscilloscopeC.Leds -> LedsC;


//vvvvvv ADDED FROM BASESTATION vvvvvv

  //components MainC, BaseStationP, LedsC;
  //components ActiveMessageC as Radio, SerialActiveMessageC as Serial;

  //MainC.Boot <- BaseStationP;

  //BaseStationP.RadioControl -> Radio;
  OscilloscopeC.SerialControl -> Serial;

  OscilloscopeC.UartSend -> Serial;
  OscilloscopeC.UartReceive -> Serial.Receive;
  OscilloscopeC.UartPacket -> Serial;
  OscilloscopeC.UartAMPacket -> Serial;

  OscilloscopeC.RadioSend -> Radio;
  OscilloscopeC.RadioReceive -> Radio.Receive;
  OscilloscopeC.RadioSnoop -> Radio.Snoop;
  OscilloscopeC.RadioPacket -> Radio;
  OscilloscopeC.RadioAMPacket -> Radio;

  //BaseStationP.Leds -> LedsC;
}
