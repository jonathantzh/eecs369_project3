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
 * Oscilloscope demo application. See README.txt file in this directory.
 *
 * @author David Gay
 */
#include "Timer.h"
#include "Oscilloscope.h"

module OscilloscopeC @safe()
{
  uses {
    interface Boot;
    interface SplitControl as RadioControl;
    interface AMSend;
    interface Receive as OsReceive;
    interface Timer<TMilli>;
    interface Read<uint16_t>;
    interface Leds;

    interface SplitControl as SerialControl;

    interface AMSend as UartSend[am_id_t id];
    interface Receive as UartReceive[am_id_t id];
    interface Packet as UartPacket;
    interface AMPacket as UartAMPacket;

    interface AMSend as RadioSend[am_id_t id];
    interface Receive as RadioReceive[am_id_t id];
    interface Receive as RadioSnoop[am_id_t id];
    interface Packet as RadioPacket;
    interface AMPacket as RadioAMPacket;

  }
}
implementation
{
  message_t sendBuf;
  bool sendBusy;

  enum {
    UART_QUEUE_LEN = 12,
    RADIO_QUEUE_LEN = 12,
  };

  /* Current local state - interval, version and accumulated readings */
  oscilloscope_t local;

  uint8_t reading; /* 0 to NREADINGS */

  /* When we head an Oscilloscope message, we check it's sample count. If
     it's ahead of ours, we "jump" forwards (set our count to the received
     count). However, we must then suppress our next count increment. This
     is a very simple form of "time" synchronization (for an abstract
     notion of time). */
  bool suppressCountChange;

//ADDED FROM BASESTATION
message_t  uartQueueBufs[UART_QUEUE_LEN];
message_t  * ONE_NOK uartQueue[UART_QUEUE_LEN];
uint8_t    uartIn, uartOut;
bool       uartBusy, uartFull;

message_t  radioQueueBufs[RADIO_QUEUE_LEN];
message_t  * ONE_NOK radioQueue[RADIO_QUEUE_LEN];
uint8_t    radioIn, radioOut;
bool       radioBusy, radioFull;

task void uartSendTask();
task void radioSendTask();

void dropBlink() {
  call Leds.led2Toggle();
}

void failBlink() {
  call Leds.led2Toggle();
}
//END ADDED FROM BASESTATION (more below)

  // Use LEDs to report various status issues. (Suggest using BASESTATION LEDs instead of Oscilloscope)
  void report_problem() { call Leds.led0Toggle(); }
  void report_sent() { call Leds.led1Toggle(); }
  void report_received() { call Leds.led2Toggle(); }

  event void Boot.booted() {
    uint8_t i;

    local.interval = DEFAULT_INTERVAL;
    local.id = TOS_NODE_ID;
    if (call RadioControl.start() != SUCCESS)
      report_problem();

//ADDED FROM BASESTATION
      for (i = 0; i < UART_QUEUE_LEN; i++)
        uartQueue[i] = &uartQueueBufs[i];
      uartIn = uartOut = 0;
      uartBusy = FALSE;
      uartFull = TRUE;

      for (i = 0; i < RADIO_QUEUE_LEN; i++)
        radioQueue[i] = &radioQueueBufs[i];
      radioIn = radioOut = 0;
      radioBusy = FALSE;
      radioFull = TRUE;

      if (call RadioControl.start() == EALREADY)
        radioFull = FALSE;
      if (call SerialControl.start() == EALREADY)
        uartFull = FALSE;
//END ADDED FROM BASESTATION (more below)
  }

  void startTimer() {
    call Timer.startPeriodic(local.interval);
    reading = 0;
  }

  event void RadioControl.startDone(error_t error) {
    startTimer();
    //ADDED FROM BASESTATION
    if (error == SUCCESS) {
      radioFull = FALSE;
    }
    //END ADDED FROM BASESTATION
  }

    //ADDED FROM BASESTATION
  event void SerialControl.startDone(error_t error) {
    if (error == SUCCESS) {
      uartFull = FALSE;
    }
  }
  event void SerialControl.stopDone(error_t error) {}
    //END ADDED FROM BASESTATION

  event void RadioControl.stopDone(error_t error) {
  }

//ADDED FROM BASESTATION
uint8_t count = 0;

message_t* ONE receive(message_t* ONE msg, void* payload, uint8_t len);

event message_t *RadioSnoop.receive[am_id_t id](message_t *msg,
              void *payload,
              uint8_t len) {
  return receive(msg, payload, len);
}

event message_t *RadioReceive.receive[am_id_t id](message_t *msg,
              void *payload,
              uint8_t len) {
  return receive(msg, payload, len);
}

message_t* receive(message_t *msg, void *payload, uint8_t len) {
  message_t *ret = msg;

  atomic {
    if (!uartFull)
{
  ret = uartQueue[uartIn];
  uartQueue[uartIn] = msg;

  uartIn = (uartIn + 1) % UART_QUEUE_LEN;

  if (uartIn == uartOut)
    uartFull = TRUE;

  if (!uartBusy)
    {
      post uartSendTask();
      uartBusy = TRUE;
    }
}
    else
dropBlink();
  }

  return ret;
}

uint8_t tmpLen;

task void uartSendTask() {
  uint8_t len;
  am_id_t id;
  am_addr_t addr, src;
  message_t* msg;
  am_group_t grp;
  atomic
    if (uartIn == uartOut && !uartFull)
{
  uartBusy = FALSE;
  return;
}

  msg = uartQueue[uartOut];
  tmpLen = len = call RadioPacket.payloadLength(msg);
  id = call RadioAMPacket.type(msg);
  addr = call RadioAMPacket.destination(msg);
  src = call RadioAMPacket.source(msg);
  grp = call RadioAMPacket.group(msg);
  call UartPacket.clear(msg);
  call UartAMPacket.setSource(msg, src);
  call UartAMPacket.setGroup(msg, grp);

  if (call UartSend.send[id](addr, uartQueue[uartOut], len) == SUCCESS)
    call Leds.led1Toggle();
  else
    {
failBlink();
post uartSendTask();
    }
}

event void UartSend.sendDone[am_id_t id](message_t* msg, error_t error) {
  if (error != SUCCESS)
    failBlink();
  else
    atomic
if (msg == uartQueue[uartOut])
  {
    if (++uartOut >= UART_QUEUE_LEN)
      uartOut = 0;
    if (uartFull)
      uartFull = FALSE;
  }
  post uartSendTask();
}

event message_t *UartReceive.receive[am_id_t id](message_t *msg,
             void *payload,
             uint8_t len) {
  message_t *ret = msg;
  bool reflectToken = FALSE;

  atomic
    if (!radioFull)
{
  reflectToken = TRUE;
  ret = radioQueue[radioIn];
  radioQueue[radioIn] = msg;
  if (++radioIn >= RADIO_QUEUE_LEN)
    radioIn = 0;
  if (radioIn == radioOut)
    radioFull = TRUE;

  if (!radioBusy)
    {
      post radioSendTask();
      radioBusy = TRUE;
    }
}
    else
dropBlink();

  if (reflectToken) {
    //call UartTokenReceive.ReflectToken(Token);
  }

  return ret;
}

task void radioSendTask() {
  uint8_t len;
  am_id_t id;
  am_addr_t addr,source;
  message_t* msg;

  atomic
    if (radioIn == radioOut && !radioFull)
{
  radioBusy = FALSE;
  return;
}

  msg = radioQueue[radioOut];
  len = call UartPacket.payloadLength(msg);
  addr = call UartAMPacket.destination(msg);
  source = call UartAMPacket.source(msg);
  id = call UartAMPacket.type(msg);

  call RadioPacket.clear(msg);
  call RadioAMPacket.setSource(msg, source);

  if (call RadioSend.send[id](addr, msg, len) == SUCCESS)
    call Leds.led0Toggle();
  else
    {
failBlink();
post radioSendTask();
    }
}

event void RadioSend.sendDone[am_id_t id](message_t* msg, error_t error) {
  if (error != SUCCESS)
    failBlink();
  else
    atomic
if (msg == radioQueue[radioOut])
  {
    if (++radioOut >= RADIO_QUEUE_LEN)
      radioOut = 0;
    if (radioFull)
      radioFull = FALSE;
  }

  post radioSendTask();
}

//END ADDED FROM BASESTATION

  event message_t* OsReceive.receive(message_t* msg, void* payload, uint8_t len) {
    oscilloscope_t *omsg = payload;

    report_received();

    /* If we receive a newer version, update our interval.
       If we hear from a future count, jump ahead but suppress our own change
    */
    if (omsg->version > local.version)
      {
	local.version = omsg->version;
	local.interval = omsg->interval;
	startTimer();
      }
    if (omsg->count > local.count)
      {
	local.count = omsg->count;
	suppressCountChange = TRUE;
      }

    return msg;
  }

  /* At each sample period:
     - if local sample buffer is full, send accumulated samples
     - read next sample
  */
  event void Timer.fired() {
    if (reading == NREADINGS)
      {
	if (!sendBusy && sizeof local <= call AMSend.maxPayloadLength())
	  {
	    // Don't need to check for null because we've already checked length
	    // above
	    memcpy(call AMSend.getPayload(&sendBuf, sizeof(local)), &local, sizeof local);
	    if (call AMSend.send(AM_BROADCAST_ADDR, &sendBuf, sizeof local) == SUCCESS)
	      sendBusy = TRUE;
	  }
	if (!sendBusy)
	  report_problem();

	reading = 0;
	/* Part 2 of cheap "time sync": increment our count if we didn't
	   jump ahead. */
	if (!suppressCountChange)
	  local.count++;
	suppressCountChange = FALSE;
      }
    if (call Read.read() != SUCCESS)
      report_problem();
  }

  event void AMSend.sendDone(message_t* msg, error_t error) {
    if (error == SUCCESS)
      report_sent();
    else
      report_problem();

    sendBusy = FALSE;
  }

  event void Read.readDone(error_t result, uint16_t data) {
    if (result != SUCCESS)
      {
	data = 0xffff;
	report_problem();
      }
    if (reading < NREADINGS)
      local.readings[reading++] = data;
  }
}
